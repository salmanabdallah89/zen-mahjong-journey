class_name SafeAreaContainer
extends MarginContainer
## Pads its children so they stay clear of notches, cutouts and system bars.
## The display safe area is reported in window pixels, so it is converted into
## the stretched canvas coordinates used by the UI before being applied.

## Extra padding (canvas units) added on top of the device safe area.
@export var base_margin: int = 32


func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var window_size := Vector2(DisplayServer.window_get_size())
	var canvas_size := get_viewport_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var safe := Rect2(DisplayServer.get_display_safe_area())
	var canvas_scale := canvas_size / window_size
	var left := 0.0
	var top := 0.0
	var right := 0.0
	var bottom := 0.0
	# On desktop the safe area describes the whole monitor, not the window, so
	# only trust it when it fits inside the window (i.e. full-screen mobile).
	if safe.size.x > 0.0 and safe.end.x <= window_size.x and safe.end.y <= window_size.y:
		left = safe.position.x * canvas_scale.x
		top = safe.position.y * canvas_scale.y
		right = (window_size.x - safe.end.x) * canvas_scale.x
		bottom = (window_size.y - safe.end.y) * canvas_scale.y

	add_theme_constant_override("margin_left", base_margin + int(left))
	add_theme_constant_override("margin_top", base_margin + int(top))
	add_theme_constant_override("margin_right", base_margin + int(right))
	add_theme_constant_override("margin_bottom", base_margin + int(bottom))
