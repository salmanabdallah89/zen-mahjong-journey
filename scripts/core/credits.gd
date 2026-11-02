class_name Credits
extends RefCounted
## Everything shown in Settings > Credits & Licences. The licence texts come
## from the engine, so they ship in every build without extra files.

const ATTRIBUTIONS: PackedStringArray = [
	"Fonts: Fraunces, Copyright The Fraunces Project Authors. Noto Naskh Arabic, Copyright 2022 The Noto Project Authors. SIL Open Font License 1.1.",
	"Pictures: Noto Emoji, Copyright Google LLC (github.com/googlefonts/noto-emoji). SIL Open Font License 1.1 and Apache License 2.0, as applicable.",
	"Engine: Godot Engine, godotengine.org. MIT License, below. Includes FreeType (The FreeType Project), ENet (Lee Salzman) and Mbed TLS (The Mbed TLS Contributors).",
	"Plugins: godot-admob, Copyright cengiz-pz. Godot Play Game Services, Copyright 2023 Jacob Ibáñez Sánchez. MIT License.",
]
## Licence names in Engine.get_license_info(), in the order shown.
const LICENCES: PackedStringArray = ["OFL-1.1", "Apache-2.0"]


## The whole page as plain text.
static func text() -> String:
	var parts := PackedStringArray()
	for credit: String in AudioCatalog.MUSIC_CREDITS:
		parts.append("Music: " + credit)
	parts.append_array(ATTRIBUTIONS)
	parts.append("MIT License\n\n" + Engine.get_license_text())
	var licences := Engine.get_license_info()
	for licence: String in LICENCES:
		parts.append("%s\n\n%s" % [licence, str(licences.get(licence, ""))])
	return "\n\n".join(parts)
