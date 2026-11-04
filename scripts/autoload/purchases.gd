extends Node
## Autoload "Purchases": the one-time "Remove Ads" purchase through Google Play
## Billing (docs/PURCHASES.md). Owning it switches off the ads between levels
## and the journey banner (AdsManager.set_ads_removed); optional reward videos
## stay, since the player chooses them.
##
## Play is the truth: on every launch the game asks Play what this Google
## account owns, so a reinstall or a new phone restores the purchase and a
## refund takes it away again. The last answer is saved, so an offline phone
## keeps its ads off. A pending payment unlocks nothing until it completes.
## Completed purchases are acknowledged (Play refunds unacknowledged ones after
## 3 days); a failed acknowledgement is retried on the next launch.
##
## Without the billing plugin (desktop, web) is_available() is false and
## nothing is offered.

## The purchase state or price changed (Settings redraws its row).
signal changed

const SECTION := "purchases"
const DIALOG_SCENE := preload("res://scenes/components/modal_dialog.tscn")
## Seconds a screen settles before the suggestion shows.
const OFFER_DELAY := 1.6

var settings_path := UserSettings.DEFAULT_PATH
## Tests set the local day (BadgeBook.today() otherwise).
var today_override := -1
var ads_removed := false
var pending := false
## Play's local price text, empty until Play has answered.
var price := ""

var _bridge: PlayBillingBridge
var _connected := false
var _dialog: ModalDialog
## The player pressed Restore: say what Play found.
var _restoring := false
## The player is in Play's purchase sheet.
var _buying := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 85
	add_child(layer)
	_dialog = DIALOG_SCENE.instantiate()
	_dialog.hide()
	layer.add_child(_dialog)
	AdsManager.ad_finished.connect(_on_ad_finished)
	restore()
	use_bridge(PlayBillingBridge.from_engine())


## Reads the saved state (the last thing Play said).
func restore() -> void:
	var settings := _settings()
	ads_removed = bool(settings.get_value(SECTION, PurchaseRules.REMOVE_ADS, false))
	pending = bool(settings.get_value(SECTION, "pending", false))
	price = ""
	AdsManager.set_ads_removed(ads_removed)


## Connects Play (the real plugin, or a test stand-in) and asks it what this
## account owns.
func use_bridge(bridge: PlayBillingBridge) -> void:
	_bridge = bridge
	_connected = false
	_buying = false
	_restoring = false
	bridge.connected.connect(_on_connected)
	bridge.product_found.connect(_on_product_found)
	bridge.purchases_listed.connect(_on_purchases_listed)
	bridge.purchases_failed.connect(_on_purchases_failed)
	bridge.purchase_updated.connect(_on_purchase_updated)
	bridge.acknowledged.connect(_on_acknowledged)
	bridge.start()


## True when Remove Ads can be bought here (Play answered with a price).
func is_available() -> bool:
	return _connected and not price.is_empty()


## True when Settings should show the Remove Ads row at all.
func shows_row() -> bool:
	return ads_removed or pending or is_available()


## Opens Play's purchase sheet.
func buy() -> void:
	if ads_removed or not is_available() or _buying:
		return
	_buying = true
	_bridge.purchase(PurchaseRules.REMOVE_ADS)


## Asks Play again what this account owns, and says what it found.
func restore_purchases() -> void:
	if not _connected:
		_say("Store Unavailable", "Google Play could not be reached. Check your connection and try again.")
		return
	_restoring = true
	_bridge.query_purchases()


## Suggests Remove Ads after a few ads between levels, never often (see
## PurchaseRules.should_offer). Returns true when the suggestion is showing.
func offer_if_due() -> bool:
	if _dialog.visible or Reminders.is_offer_open():
		return false
	var settings := _settings()
	var offers := int(settings.get_value(SECTION, "offers", 0))
	if not PurchaseRules.should_offer(ads_removed, pending, is_available(), int(settings.get_value(SECTION, "ads_since_offer", 0)),
			offers, int(settings.get_value(SECTION, "last_offer_day", 0)), _today()):
		return false
	settings.set_value(SECTION, "offers", offers + 1)
	settings.set_value(SECTION, "last_offer_day", _today())
	settings.set_value(SECTION, "ads_since_offer", 0)
	_dialog.open("A Quieter Garden",
			"Remove the ads between levels and on the map with one purchase of %s. It is yours for good on this Google account. Reward videos for extra hints stay optional." % price)
	_dialog.add_action("Remove Ads · %s" % price, buy, true)
	_dialog.add_action("Not Now", func() -> void: pass)
	return true


## Suggests after the screen has settled, unless a level is open by then.
func offer_later(tree: SceneTree) -> void:
	tree.create_timer(OFFER_DELAY).timeout.connect(func() -> void:
		var scene := tree.current_scene
		if scene != null and scene.scene_file_path != GameSession.GAME_SCENE:
			offer_if_due())


func is_dialog_open() -> bool:
	return _dialog.visible


## Closes the suggestion or message as "Not Now" (Android back).
func close_dialog() -> void:
	_dialog.close()


func _on_connected() -> void:
	_connected = true
	_bridge.query_product(PurchaseRules.REMOVE_ADS)
	_bridge.query_purchases()


func _on_product_found(product: String, local_price: String, _title: String) -> void:
	if product == PurchaseRules.REMOVE_ADS:
		price = local_price
		changed.emit()


## Play's full list for this account: it can grant (restore) and take away
## (refund). Only a successful answer is trusted, never a failed query.
func _on_purchases_listed(purchases: Array) -> void:
	var was_owned := ads_removed
	var found := _apply(purchases, true)
	if _restoring:
		_restoring = false
		if found.owned and not was_owned:
			_say("Purchase Restored", "Ads are off again. Thank you for supporting Zen Mahjong Journey!")
		elif found.owned:
			_say("All Set", "Remove Ads is already active on this Google account.")
		elif found.pending:
			_say_pending()
		else:
			_say("Nothing to Restore", "This Google account has no Remove Ads purchase. Purchases belong to the Google account that made them.")


func _on_purchases_failed(_code: int) -> void:
	if _restoring:
		_restoring = false
		_say("Store Unavailable", "Google Play could not be reached. Check your connection and try again.")


func _on_purchase_updated(code: int, purchases: Array) -> void:
	_buying = false
	match code:
		PurchaseRules.OK:
			var found := _apply(purchases, false)
			if found.owned:
				AudioManager.play_sfx("unlock")
				_say("Thank You!", "Ads are gone for good on this Google account. Enjoy the quiet garden.")
			elif found.pending:
				_say_pending()
		PurchaseRules.USER_CANCELED:
			pass
		PurchaseRules.ITEM_ALREADY_OWNED:
			# Bought earlier (another phone, a reinstall): Play's list grants it.
			restore_purchases()
		_:
			_say("Purchase Not Completed", "Google Play could not finish the purchase, and nothing was charged. Please try again later.")


func _on_acknowledged(_token: String, _code: int) -> void:
	# A failed acknowledgement shows up unacknowledged on the next launch's list.
	pass


## Applies a purchase list. A complete list (`whole_list`) may also take Remove
## Ads away (a refund) or clear a pending payment that was declined.
func _apply(purchases: Array, whole_list: bool) -> Dictionary:
	var found := PurchaseRules.read(purchases)
	for token: String in found.to_acknowledge:
		_bridge.acknowledge(token)
	if found.owned:
		_set_state(true, false)
	elif found.pending:
		_set_state(ads_removed, true)
	elif whole_list:
		_set_state(false, false)
	return found


func _set_state(owned: bool, is_pending: bool) -> void:
	if owned == ads_removed and is_pending == pending:
		return
	ads_removed = owned
	pending = is_pending
	var settings := _settings()
	settings.set_value(SECTION, PurchaseRules.REMOVE_ADS, owned)
	settings.set_value(SECTION, "pending", is_pending)
	AdsManager.set_ads_removed(owned)
	changed.emit()


func _on_ad_finished(kind: String, _placement: String, _rewarded: bool) -> void:
	if kind == "interstitial":
		var settings := _settings()
		settings.set_value(SECTION, "ads_since_offer", int(settings.get_value(SECTION, "ads_since_offer", 0)) + 1)


func _say_pending() -> void:
	_say("Payment Pending", "Your payment is still being processed. Ads will switch off as soon as Google Play confirms it.")


func _say(title: String, message: String) -> void:
	_dialog.open(title, message)
	_dialog.add_action("OK", func() -> void: pass, true)


func _settings() -> UserSettings:
	return UserSettings.new(settings_path)


func _today() -> int:
	return today_override if today_override >= 0 else BadgeBook.today()
