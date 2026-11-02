class_name UpdateNotes
extends RefCounted
## Decides whether to tell the player about a newer version, from the small
## file published with the web build (site/version.json, docs/UPDATES.md).

const VERSION_URL := "https://salmanabdallah89.github.io/zen-mahjong-journey/version.json"
const STORE_URL := "https://play.google.com/store/apps/details?id=com.zenmahjongjourney.game"
## "Later" keeps a version quiet for this many days.
const SNOOZE_DAYS := 3
const MAX_NOTES := 4


## True if `latest` ("1.2.10") is a higher version than `current`.
static func is_newer(latest: String, current: String) -> bool:
	var a := latest.split(".")
	var b := current.split(".")
	for i in maxi(a.size(), b.size()):
		var left := a[i].to_int() if i < a.size() else 0
		var right := b[i].to_int() if i < b.size() else 0
		if left != right:
			return left > right
	return false


## The published file as {"latest": String, "notes": PackedStringArray}, or
## empty when it is damaged.
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary or not str(data.get("latest", "")).left(1).is_valid_int():
		return {}
	var notes := PackedStringArray()
	var listed: Variant = data.get("notes", [])
	if listed is Array:
		for note: Variant in listed.slice(0, MAX_NOTES):
			notes.append(str(note))
	return {"latest": str(data.latest), "notes": notes}


static func should_show(latest: String, current: String, snoozed_version: String, snoozed_day: int, today: int) -> bool:
	if not is_newer(latest, current):
		return false
	return latest != snoozed_version or today >= snoozed_day + SNOOZE_DAYS
