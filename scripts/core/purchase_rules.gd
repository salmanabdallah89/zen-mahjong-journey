class_name PurchaseRules
extends RefCounted
## The one-time "Remove Ads" purchase (docs/PURCHASES.md): what Google Play's
## purchase list means for the player, and when the game may suggest buying.

## The Play Console product id (a one-time, non-consumable in-app product).
## Ids can never be reused, so never change it.
const REMOVE_ADS := "remove_ads"
## Play's Purchase.PurchaseState values.
const PURCHASED := 1
const PENDING := 2
## Play's BillingResponseCode values the game tells apart.
const OK := 0
const USER_CANCELED := 1
const ITEM_ALREADY_OWNED := 7
## The suggestion waits until the player has seen this many ads between
## levels, comes back at most this often, and stops after this many "Not Now".
const OFFER_AFTER_INTERSTITIALS := 3
const OFFER_GAP_DAYS := 7
const MAX_OFFERS := 3


## Reads Play's purchase list for `product`:
## {"owned": bool, "pending": bool, "to_acknowledge": Array[String] of tokens}.
## Only a completed purchase counts; a pending payment unlocks nothing yet.
static func read(purchases: Array, product := REMOVE_ADS) -> Dictionary:
	var result := {"owned": false, "pending": false, "to_acknowledge": [] as Array[String]}
	for entry: Variant in purchases:
		if not entry is Dictionary:
			continue
		var products: Variant = entry.get("products", [])
		if not products is Array or not product in products:
			continue
		match int(entry.get("state", 0)):
			PURCHASED:
				result.owned = true
				if not bool(entry.get("acknowledged", false)) and not str(entry.get("token", "")).is_empty():
					(result.to_acknowledge as Array[String]).append(str(entry.token))
			PENDING:
				result.pending = true
	if result.owned:
		result.pending = false
	return result


## Parses the plugin's JSON purchase list (anything damaged reads as empty).
static func parse(json: String) -> Array:
	var parser := JSON.new()
	if parser.parse(json) != OK:
		return []
	return parser.data if parser.data is Array else []


## True when the game may suggest Remove Ads: not owned or pending, the price
## is known, enough ads were seen since the last suggestion, and it was not
## suggested too often or too recently.
static func should_offer(owned: bool, pending: bool, price_known: bool, ads_since: int, offers: int,
		last_offer_day: int, today: int) -> bool:
	if owned or pending or not price_known or offers >= MAX_OFFERS:
		return false
	if ads_since < OFFER_AFTER_INTERSTITIALS:
		return false
	return offers == 0 or today - last_offer_day >= OFFER_GAP_DAYS
