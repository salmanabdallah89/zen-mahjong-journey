class_name PlayBillingBridge
extends RefCounted
## Google Play Billing as the game sees it. Wraps the ZenPlayBilling Android
## plugin (addons/zen_play_billing, source in android_plugins/play_billing) or
## a test stand-in that overrides these methods and emits the same signals.
## Anywhere without the plugin (desktop, web, sideloaded without Play) nothing
## is sold and is_available() is false.

signal connected
signal connect_failed(code: int)
## Play's local price text ("$3.99", "3,99 €") and the product name.
signal product_found(product: String, price: String, title: String)
signal product_missing(product: String, code: int)
## Every one-time purchase the Google account owns or has pending.
signal purchases_listed(purchases: Array)
signal purchases_failed(code: int)
## The purchase sheet's outcome (PurchaseRules.OK, USER_CANCELED, ...).
signal purchase_updated(code: int, purchases: Array)
signal acknowledged(token: String, code: int)

const PLUGIN_NAME := "ZenPlayBilling"

var _plugin: Object


static func from_engine() -> PlayBillingBridge:
	var bridge := PlayBillingBridge.new()
	if OS.get_name() == "Android" and Engine.has_singleton(PLUGIN_NAME):
		bridge.use_plugin(Engine.get_singleton(PLUGIN_NAME))
	return bridge


func use_plugin(plugin: Object) -> void:
	_plugin = plugin
	if plugin == null:
		return
	plugin.connect("connected", func() -> void: connected.emit())
	plugin.connect("connect_failed", func(code: int, _message: String) -> void: connect_failed.emit(code))
	plugin.connect("product_found", func(product: String, price: String, title: String) -> void:
		product_found.emit(product, price, title))
	plugin.connect("product_missing", func(product: String, code: int) -> void: product_missing.emit(product, code))
	plugin.connect("purchases_listed", func(json: String) -> void: purchases_listed.emit(PurchaseRules.parse(json)))
	plugin.connect("purchases_failed", func(code: int) -> void: purchases_failed.emit(code))
	plugin.connect("purchase_updated", func(code: int, json: String) -> void:
		purchase_updated.emit(code, PurchaseRules.parse(json)))
	plugin.connect("acknowledged", func(token: String, code: int) -> void: acknowledged.emit(token, code))


func is_available() -> bool:
	return _plugin != null


func start() -> void:
	if _plugin != null:
		_plugin.call("startConnection")


func query_product(product: String) -> void:
	if _plugin != null:
		_plugin.call("queryProduct", product)


func query_purchases() -> void:
	if _plugin != null:
		_plugin.call("queryPurchases")


## Opens Play's purchase sheet; the outcome comes through purchase_updated.
func purchase(product: String) -> void:
	if _plugin != null:
		_plugin.call("purchase", product)


func acknowledge(token: String) -> void:
	if _plugin != null:
		_plugin.call("acknowledge", token)
