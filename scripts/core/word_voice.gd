class_name WordVoice
extends RefCounted
## Reads a word aloud with the device's own text-to-speech voice. Devices
## without a voice for the language simply stay silent.

## The last word sent to a voice (tests).
static var last_spoken := ""


static func can_speak(language: String) -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) \
		and not DisplayServer.tts_get_voices_for_language(language).is_empty()


static func speak(text: String, language: String) -> void:
	if AudioManager.muted or not can_speak(language):
		return
	last_spoken = text
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, DisplayServer.tts_get_voices_for_language(language)[0], roundi(AudioManager.sfx_volume * 100.0))
