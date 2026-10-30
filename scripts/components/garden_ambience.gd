class_name GardenAmbience
extends Control
## The living layer over a garden painting: soft light rays from the
## painting's light source, slow drifting mist, falling petals (or leaves)
## and glowing motes (fireflies at night). Built in code from AmbienceStyle,
## so every garden, old art or HD repaint, gets the same treatment.
##
## Sits right above the background and under the shade, HUD and board, and
## never takes input. With reduced animations only the still light and still
## mist remain: no particles, no sway, no drifting.

const PETAL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/effects/petal_01.png"),
	preload("res://assets/effects/petal_04.png"),
]
## Light rays: angle offsets (degrees) and widths (fraction of screen width).
const RAY_ANGLES := [-15.0, -6.0, 3.0, 11.0]
const RAY_WIDTHS := [0.16, 0.24, 0.12, 0.2]
const RAY_BREATH_SECONDS := 7.0
const RAY_SWAY_SECONDS := 11.0
const RAY_SWAY := 0.035
## Mist bands: {top, height} as fractions of the screen height, strength factor.
const MIST_BANDS := [[0.24, 0.32, 1.0], [0.62, 0.34, 0.7]]
const MIST_SECONDS := 80.0

const MIST_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float speed = 0.0;
uniform float offset = 0.0;
void fragment() {
	vec2 uv = vec2(fract(UV.x * 0.8 + offset + TIME * speed), UV.y);
	float n = smoothstep(0.32, 0.85, texture(TEXTURE, uv).r);
	float fade = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.6, UV.y);
	COLOR = vec4(tint.rgb, tint.a * n * fade);
}
"""

var background := ""
var _rays: Control
var _tweens: Array[Tween] = []

static var _glow: GradientTexture2D
static var _mist_noise: NoiseTexture2D
static var _mist_shader: Shader


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout)
	Motion.changed.connect(_on_motion_changed)


## Puts a layer right above `background` (in front of it, behind everything
## after it), covering the whole screen.
static func add_over(background: Control) -> GardenAmbience:
	var ambience := GardenAmbience.new()
	ambience.name = "Ambience"
	background.add_sibling(ambience)
	ambience.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return ambience


## (Re)builds the layer for a garden, e.g. "bg_golden_sakura".
func setup(garden: String) -> void:
	background = garden
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rays = null
	if AmbienceStyle.mist(garden) > 0.0:
		for band: Array in MIST_BANDS:
			_add_mist(band)
	if AmbienceStyle.rays(garden) > 0.0:
		_add_rays()
	if not Motion.reduced:
		var petals := AmbienceStyle.petals(garden)
		for i in PETAL_TEXTURES.size():
			var count := petals / PETAL_TEXTURES.size() + (1 if i < petals % PETAL_TEXTURES.size() else 0)
			if count > 0:
				_add_petals(PETAL_TEXTURES[i], count)
		if AmbienceStyle.motes(garden) > 0:
			_add_motes(AmbienceStyle.motes(garden))
	_layout()


## Particles currently falling or floating (tests).
func particle_count() -> int:
	var total := 0
	for child in get_children():
		if child is CPUParticles2D and (child as CPUParticles2D).emitting:
			total += (child as CPUParticles2D).amount
	return total


func has_rays() -> bool:
	return _rays != null


func _on_motion_changed(_reduced: bool) -> void:
	setup(background)


func _layout() -> void:
	for child in get_children():
		if child is CPUParticles2D:
			var particles := child as CPUParticles2D
			if particles.name.begins_with("Petals"):
				particles.position = Vector2(size.x / 2.0, -60.0)
				particles.emission_rect_extents = Vector2(size.x * 0.6, 10.0)
				# Long enough to fall past the bottom edge.
				particles.lifetime = maxf(size.y / 70.0, 8.0)
				particles.preprocess = particles.lifetime
			else:
				particles.position = size / 2.0
				particles.emission_rect_extents = size / 2.0
		elif child.name.begins_with("Mist"):
			var band: Array = child.get_meta("band")
			var mist := child as TextureRect
			mist.position = Vector2(0.0, size.y * float(band[0]))
			mist.size = Vector2(size.x, size.y * float(band[1]))
	if _rays != null:
		_rays.size = size
		_rays.pivot_offset = _ray_source()
		_rays.queue_redraw()


func _add_rays() -> void:
	_rays = Control.new()
	_rays.name = "Rays"
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rays.material = material
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	if Motion.reduced:
		return
	var breath := _rays.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_rays, "modulate:a", 0.6, RAY_BREATH_SECONDS)
	breath.tween_property(_rays, "modulate:a", 1.0, RAY_BREATH_SECONDS)
	var sway := _rays.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(_rays, "rotation", RAY_SWAY * -AmbienceStyle.ray_side(background), RAY_SWAY_SECONDS)
	sway.tween_property(_rays, "rotation", 0.0, RAY_SWAY_SECONDS)
	_tweens.append_array([breath, sway])


func _ray_source() -> Vector2:
	var side := AmbienceStyle.ray_side(background)
	return Vector2(size.x * (0.5 + 0.6 * side), -size.y * 0.08)


func _draw_rays() -> void:
	var source := _ray_source()
	var side := AmbienceStyle.ray_side(background)
	# Aim from the corner towards the lower middle of the screen.
	var aim := (Vector2(size.x * 0.5, size.y * 0.75) - source).angle()
	var length := size.length() * 1.1
	var tint := AmbienceStyle.tint(background, "ray_tint")
	var strength := AmbienceStyle.rays(background)
	for i in RAY_ANGLES.size():
		var angle := aim + deg_to_rad(float(RAY_ANGLES[i])) * -side
		var along := Vector2.from_angle(angle)
		var across := along.orthogonal()
		var half_end := size.x * float(RAY_WIDTHS[i]) / 2.0
		var half_start := half_end * 0.25
		var end := source + along * length
		var bright := Color(tint, strength * (0.7 + 0.3 * float(i % 2)))
		var clear := Color(tint, 0.0)
		_rays.draw_polygon(PackedVector2Array([source - across * half_start, source + across * half_start,
			end + across * half_end, end - across * half_end]), PackedColorArray([bright, bright, clear, clear]))


func _add_mist(band: Array) -> void:
	var mist := TextureRect.new()
	mist.name = "Mist%d" % get_child_count()
	mist.set_meta("band", band)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist.texture = _noise()
	mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mist.stretch_mode = TextureRect.STRETCH_SCALE
	mist.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var material := ShaderMaterial.new()
	material.shader = _shader()
	var tint := AmbienceStyle.tint(background, "mist_tint")
	tint.a = AmbienceStyle.mist(background) * float(band[2])
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("offset", float(band[0]))
	# Opposite directions per band, so the mist folds slowly into itself.
	var direction := 1.0 if get_child_count() % 2 == 0 else -1.0
	material.set_shader_parameter("speed", 0.0 if Motion.reduced else direction / MIST_SECONDS)
	mist.material = material
	add_child(mist)


func _add_petals(texture: Texture2D, count: int) -> void:
	var petals := CPUParticles2D.new()
	petals.name = "Petals%d" % get_child_count()
	petals.amount = count
	petals.texture = texture
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.direction = Vector2(0.3 * -AmbienceStyle.ray_side(background), 1.0)
	petals.spread = 25.0
	petals.gravity = Vector2(10.0 * -AmbienceStyle.ray_side(background), 24.0)
	petals.initial_velocity_min = 35.0
	petals.initial_velocity_max = 80.0
	petals.angular_velocity_min = -45.0
	petals.angular_velocity_max = 45.0
	petals.angle_min = -180.0
	petals.angle_max = 180.0
	petals.scale_amount_min = 0.3
	petals.scale_amount_max = 0.6
	petals.color = AmbienceStyle.tint(background, "petal_tint")
	petals.color_ramp = _fade(PackedFloat32Array([0.0, 0.08, 0.85, 1.0]), PackedFloat32Array([0.0, 0.95, 0.95, 0.0]))
	add_child(petals)


func _add_motes(count: int) -> void:
	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.amount = count
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.texture = _glow_texture()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = material
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 180.0
	motes.gravity = Vector2(0.0, -3.0)
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 18.0
	motes.scale_amount_min = 0.45
	motes.scale_amount_max = 1.0
	motes.color = AmbienceStyle.tint(background, "mote_tint")
	# Fade in, twinkle once, fade out.
	motes.color_ramp = _fade(PackedFloat32Array([0.0, 0.2, 0.45, 0.65, 1.0]),
		PackedFloat32Array([0.0, 0.9, 0.35, 0.9, 0.0]))
	add_child(motes)


static func _fade(offsets: PackedFloat32Array, alphas: PackedFloat32Array) -> Gradient:
	var gradient := Gradient.new()
	var colors := PackedColorArray()
	for alpha in alphas:
		colors.append(Color(1, 1, 1, alpha))
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient


## A soft round glow (white, so the particle colour tints it).
static func _glow_texture() -> GradientTexture2D:
	if _glow == null:
		_glow = GradientTexture2D.new()
		_glow.width = 64
		_glow.height = 64
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)
		_glow.gradient = _fade(PackedFloat32Array([0.0, 0.2, 1.0]), PackedFloat32Array([1.0, 0.6, 0.0]))
	return _glow


static func _noise() -> NoiseTexture2D:
	if _mist_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.008
		noise.fractal_octaves = 3
		_mist_noise = NoiseTexture2D.new()
		_mist_noise.width = 512
		_mist_noise.height = 256
		_mist_noise.seamless = true
		_mist_noise.noise = noise
	return _mist_noise


static func _shader() -> Shader:
	if _mist_shader == null:
		_mist_shader = Shader.new()
		_mist_shader.code = MIST_SHADER
	return _mist_shader
