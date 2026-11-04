extends TestCase
## What Play's purchase list means for Remove Ads, and when it is suggested.


func _purchase(state: int, acknowledged := true, product := PurchaseRules.REMOVE_ADS, token := "t1") -> Dictionary:
	return {"products": [product], "state": state, "token": token, "acknowledged": acknowledged}


func test_only_a_completed_purchase_removes_ads() -> void:
	assert_false(PurchaseRules.read([]).owned, "nothing bought")
	assert_true(PurchaseRules.read([_purchase(PurchaseRules.PURCHASED)]).owned, "bought")
	var waiting := PurchaseRules.read([_purchase(PurchaseRules.PENDING)])
	assert_false(waiting.owned, "a pending payment unlocks nothing")
	assert_true(waiting.pending, "but is reported as pending")
	assert_false(PurchaseRules.read([_purchase(PurchaseRules.PURCHASED, true, "other")]).owned, "another product")
	assert_false(PurchaseRules.read([_purchase(0)]).owned, "unknown state")
	var both := PurchaseRules.read([_purchase(PurchaseRules.PENDING), _purchase(PurchaseRules.PURCHASED, true, PurchaseRules.REMOVE_ADS, "t2")])
	assert_true(both.owned and not both.pending, "owned wins over an old pending entry")


func test_unacknowledged_purchases_are_listed_for_acknowledgement() -> void:
	var fresh := PurchaseRules.read([_purchase(PurchaseRules.PURCHASED, false)])
	assert_eq(fresh.to_acknowledge, ["t1"] as Array[String], "fresh purchase")
	assert_true(PurchaseRules.read([_purchase(PurchaseRules.PURCHASED)]).to_acknowledge.is_empty(), "already acknowledged")
	assert_true(PurchaseRules.read([_purchase(PurchaseRules.PENDING, false)]).to_acknowledge.is_empty(), "pending is not acknowledged")


func test_damaged_lists_read_as_empty() -> void:
	assert_eq(PurchaseRules.parse("not json"), [], "not json")
	assert_eq(PurchaseRules.parse("{}"), [], "not a list")
	assert_eq(PurchaseRules.parse("[]"), [], "empty list")
	assert_false(PurchaseRules.read(["junk", {"products": "remove_ads", "state": 1}]).owned, "junk entries")
	assert_true(PurchaseRules.read(PurchaseRules.parse('[{"products":["remove_ads"],"state":1,"token":"a","acknowledged":true}]')).owned, "plugin JSON")


func test_the_suggestion_waits_and_stays_rare() -> void:
	var due := PurchaseRules.OFFER_AFTER_INTERSTITIALS
	assert_true(PurchaseRules.should_offer(false, false, true, due, 0, 0, 100), "first time after a few ads")
	assert_false(PurchaseRules.should_offer(false, false, true, due - 1, 0, 0, 100), "too few ads seen")
	assert_false(PurchaseRules.should_offer(true, false, true, due, 0, 0, 100), "already bought")
	assert_false(PurchaseRules.should_offer(false, true, true, due, 0, 0, 100), "payment pending")
	assert_false(PurchaseRules.should_offer(false, false, false, due, 0, 0, 100), "no price from Play")
	assert_false(PurchaseRules.should_offer(false, false, true, due, 1, 100, 100 + PurchaseRules.OFFER_GAP_DAYS - 1), "too soon after the last one")
	assert_true(PurchaseRules.should_offer(false, false, true, due, 1, 100, 100 + PurchaseRules.OFFER_GAP_DAYS), "a week later")
	assert_false(PurchaseRules.should_offer(false, false, true, due, PurchaseRules.MAX_OFFERS, 0, 1000), "stops after a few Not Now")
