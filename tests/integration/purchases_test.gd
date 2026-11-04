extends Node
## Remove Ads with a stand-in Google Play (_FakeBilling): the Settings row and
## price, buying and acknowledging, ads switching off at once, a pending
## payment, cancel and errors, restore, refunds, an offline launch, and the
## rare suggestion on the journey map. The real plugin only runs on a phone.
##   godot --headless --path . res://tests/integration/purchases_test.tscn

const SETTINGS_SCENE := preload("res://scenes/components/audio_settings.tscn")
const SETTINGS_PATH := "user://test_purchases.cfg"

var _failures := PackedStringArray()
var _checks := 0


class _FakeBilling extends PlayBillingBridge:
	var online := true
	var price_text := "$3.99"
	var owned: Array = []
	var bought: Array[String] = []
	var acknowledged_tokens: Array[String] = []
	var queries := 0

	func is_available() -> bool:
		return true

	func start() -> void:
		if online:
			connected.emit()
		else:
			connect_failed.emit(2)

	func query_product(product: String) -> void:
		product_found.emit(product, price_text, "Remove Ads")

	func query_purchases() -> void:
		queries += 1
		if online:
			purchases_listed.emit(owned)
		else:
			purchases_failed.emit(2)

	func purchase(product: String) -> void:
		bought.append(product)

	func acknowledge(token: String) -> void:
		acknowledged_tokens.append(token)
		acknowledged.emit(token, PurchaseRules.OK)


static func _entry(state: int, acknowledged := false, token := "token-1") -> Dictionary:
	return {"products": [PurchaseRules.REMOVE_ADS], "state": state, "token": token, "acknowledged": acknowledged}


func _ready() -> void:
	SafeConfig.remove_all(SETTINGS_PATH)
	Purchases.settings_path = SETTINGS_PATH
	Purchases.restore()
	_check(not Purchases.is_available() and not Purchases.shows_row(), "desktop runs sell nothing")
	var panel: AudioSettingsPanel = SETTINGS_SCENE.instantiate()
	add_child(panel)
	panel.open()
	_check(not (panel.get_node("%PurchaseRow") as Control).visible, "no Remove Ads row without Play")
	panel.queue_free()
	await _frames(1)

	await _test_buying()
	await _test_launches()
	await _test_pending_and_errors()
	await _test_restore()
	await _test_offer()

	Purchases.close_dialog()
	AdsManager.hide_banner()
	SafeConfig.remove_all(SETTINGS_PATH)
	Purchases.settings_path = UserSettings.DEFAULT_PATH
	Purchases.today_override = -1
	Purchases.use_bridge(PlayBillingBridge.new())
	Purchases.restore()
	for failure in _failures:
		push_error("FAIL: " + failure)
	print("purchases: %d checks, %d failed" % [_checks, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _test_buying() -> void:
	var fake := _FakeBilling.new()
	Purchases.use_bridge(fake)
	_check(Purchases.is_available() and Purchases.price == "$3.99", "Play's price is shown")
	_check(not Purchases.ads_removed and fake.queries == 1, "a launch asks Play what the account owns")

	AdsManager.show_banner()
	_check(AdsManager.is_banner_visible(), "the journey banner shows before buying")
	var panel: AudioSettingsPanel = SETTINGS_SCENE.instantiate()
	add_child(panel)
	panel.open()
	await _frames(2)
	var buy: Button = panel.get_node("%RemoveAdsButton")
	var restore: Button = panel.get_node("%RestoreButton")
	_check((panel.get_node("%PurchaseRow") as Control).visible, "Settings shows the Remove Ads row")
	_check(buy.visible and buy.text == "Remove Ads · $3.99", "the button carries the price")
	_check(restore.visible, "Restore Purchase is offered")
	_check(buy.size.y >= 120.0 and restore.size.y >= 120.0, "touch targets")
	buy.pressed.emit()
	_check(fake.bought == ([PurchaseRules.REMOVE_ADS] as Array[String]), "Play's purchase sheet opens")
	buy.pressed.emit()
	_check(fake.bought.size() == 1, "a second tap while the sheet is open does nothing")

	fake.owned = [_entry(PurchaseRules.PURCHASED)]
	fake.purchase_updated.emit(PurchaseRules.OK, fake.owned)
	await _frames(1)
	_check(Purchases.ads_removed and AdsManager.ads_removed, "buying removes ads")
	_check(fake.acknowledged_tokens == (["token-1"] as Array[String]), "the purchase is acknowledged")
	_check(not AdsManager.is_banner_visible(), "the banner goes at once")
	_check(_dialog_title() == "Thank You!", "a thank-you shows")
	_check(not buy.visible and not restore.visible, "Settings no longer sells")
	_check((panel.get_node("%PurchaseStatus") as Label).visible, "Settings says ads are removed")
	Purchases.close_dialog()
	panel.queue_free()

	AdsManager.show_banner()
	_check(not AdsManager.is_banner_visible(), "no banner after buying")
	var state := {"ran": false}
	AdsManager.levels_ended = 1
	AdsManager.last_ad_ended_msec = -1
	AdsManager.after_level_complete(func() -> void: state.ran = true)
	_check(state.ran and not AdsManager.is_showing(), "no ad between levels after buying")
	var rewarded := {"done": false}
	AdsManager.show_rewarded("hint", func(_watched: bool) -> void: rewarded.done = true)
	_check(AdsManager.is_showing(), "reward videos stay available on request")
	AdsManager.cancel()
	AdsManager.hide_banner()
	await _frames(1)


func _test_launches() -> void:
	# Next launch, offline: the saved answer keeps ads off.
	Purchases.restore()
	var offline := _FakeBilling.new()
	offline.online = false
	Purchases.use_bridge(offline)
	_check(Purchases.ads_removed and AdsManager.ads_removed, "offline launches keep ads off")
	_check(not Purchases.is_available(), "nothing is sold offline")
	offline.purchases_failed.emit(6)
	_check(Purchases.ads_removed, "a failed query never takes the purchase away")

	# Online again with the purchase listed but not yet acknowledged.
	var fake := _FakeBilling.new()
	fake.owned = [_entry(PurchaseRules.PURCHASED, false, "late")]
	Purchases.use_bridge(fake)
	_check(fake.acknowledged_tokens == (["late"] as Array[String]), "a missed acknowledgement is retried")

	# Refunded: Play no longer lists it.
	var refunded := _FakeBilling.new()
	Purchases.use_bridge(refunded)
	_check(not Purchases.ads_removed and not AdsManager.ads_removed, "a refund brings ads back")
	Purchases.restore()
	_check(not Purchases.ads_removed, "and that is saved")
	await _frames(1)


func _test_pending_and_errors() -> void:
	var fake := _FakeBilling.new()
	Purchases.use_bridge(fake)
	Purchases.buy()
	fake.purchase_updated.emit(PurchaseRules.OK, [_entry(PurchaseRules.PENDING)])
	_check(not Purchases.ads_removed and Purchases.pending, "a pending payment unlocks nothing yet")
	_check(fake.acknowledged_tokens.is_empty(), "pending purchases are not acknowledged")
	_check(_dialog_title() == "Payment Pending", "the player is told it is pending")
	Purchases.close_dialog()
	var panel: AudioSettingsPanel = SETTINGS_SCENE.instantiate()
	add_child(panel)
	panel.open()
	await _frames(1)
	_check(not (panel.get_node("%RemoveAdsButton") as Button).visible, "no second purchase while pending")
	_check((panel.get_node("%PurchaseStatus") as Label).visible, "Settings says the payment is pending")
	# The payment completes while the game is open.
	fake.purchase_updated.emit(PurchaseRules.OK, [_entry(PurchaseRules.PURCHASED, false, "paid")])
	_check(Purchases.ads_removed and not Purchases.pending, "a completed payment removes ads")
	_check(fake.acknowledged_tokens == (["paid"] as Array[String]), "and is acknowledged")
	Purchases.close_dialog()
	panel.queue_free()

	# A declined payment disappears from Play's list.
	var declined := _FakeBilling.new()
	Purchases.use_bridge(declined)
	_check(not Purchases.ads_removed and not Purchases.pending, "a refund or declined payment clears the state")

	Purchases.buy()
	declined.purchase_updated.emit(PurchaseRules.USER_CANCELED, [])
	_check(not Purchases.is_dialog_open() and not Purchases.ads_removed, "cancelling says nothing")
	Purchases.buy()
	_check(declined.bought.size() == 2, "the player can try again after cancelling")
	declined.purchase_updated.emit(6, [])
	_check(_dialog_title() == "Purchase Not Completed", "an error is explained")
	Purchases.close_dialog()
	await _frames(1)


func _test_restore() -> void:
	var fake := _FakeBilling.new()
	Purchases.use_bridge(fake)
	Purchases.restore_purchases()
	_check(_dialog_title() == "Nothing to Restore", "restore with nothing bought")
	Purchases.close_dialog()

	# Bought on another phone: Play says "already owned", the list grants it.
	fake.owned = [_entry(PurchaseRules.PURCHASED, true)]
	Purchases.buy()
	fake.purchase_updated.emit(PurchaseRules.ITEM_ALREADY_OWNED, [])
	_check(Purchases.ads_removed, "an earlier purchase is restored")
	_check(_dialog_title() == "Purchase Restored", "the player is told")
	Purchases.close_dialog()
	Purchases.restore_purchases()
	_check(_dialog_title() == "All Set", "restore when already active")
	Purchases.close_dialog()

	var offline := _FakeBilling.new()
	offline.online = false
	Purchases.use_bridge(offline)
	Purchases.restore_purchases()
	_check(_dialog_title() == "Store Unavailable", "restore offline")
	Purchases.close_dialog()
	# Back to a player who has not bought.
	Purchases.use_bridge(_FakeBilling.new())
	await _frames(1)


func _test_offer() -> void:
	Purchases.today_override = 100
	_check(not Purchases.ads_removed, "offer tests start without the purchase")
	_check(not Purchases.offer_if_due(), "no suggestion before any ads")
	for i in PurchaseRules.OFFER_AFTER_INTERSTITIALS:
		AdsManager.ad_finished.emit("interstitial", "level_complete", false)
	AdsManager.ad_finished.emit("rewarded", "hint", true)
	_check(Purchases.offer_if_due(), "suggested after a few ads between levels")
	_check(_dialog_title() == "A Quieter Garden", "the suggestion's title")
	var buttons := _dialog_buttons()
	_check(buttons.size() == 2 and buttons[0].text == "Remove Ads · $3.99" and buttons[1].text == "Not Now", "buy or not now")
	buttons[1].pressed.emit()
	_check(not Purchases.is_dialog_open(), "Not Now closes it")
	for i in PurchaseRules.OFFER_AFTER_INTERSTITIALS:
		AdsManager.ad_finished.emit("interstitial", "level_complete", false)
	_check(not Purchases.offer_if_due(), "not again within a week")
	Purchases.today_override = 100 + PurchaseRules.OFFER_GAP_DAYS
	_check(Purchases.offer_if_due(), "again a week later")
	var fake := _FakeBilling.new()
	Purchases.use_bridge(fake)
	_dialog_buttons()[0].pressed.emit()
	_check(fake.bought.size() == 1, "the suggestion's button opens Play's sheet")
	fake.purchase_updated.emit(PurchaseRules.USER_CANCELED, [])
	Purchases.today_override = 200
	for i in PurchaseRules.OFFER_AFTER_INTERSTITIALS:
		AdsManager.ad_finished.emit("interstitial", "level_complete", false)
	_check(Purchases.offer_if_due(), "a third time, much later")
	Purchases.close_dialog()
	Purchases.today_override = 300
	for i in PurchaseRules.OFFER_AFTER_INTERSTITIALS:
		AdsManager.ad_finished.emit("interstitial", "level_complete", false)
	_check(not Purchases.offer_if_due(), "never more than three times")
	await _frames(1)


func _dialog_title() -> String:
	if not Purchases.is_dialog_open():
		return ""
	return (Purchases.find_child("Title", true, false) as Label).text


func _dialog_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for button in Purchases.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion():
			found.append(button)
	return found


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
