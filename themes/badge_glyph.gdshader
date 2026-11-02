shader_type canvas_item;
// Strikes a colour picture into one metal: its brightness picks a shade between
// `dark`, `mid` and `light`, so a picture reads as a raised relief. Gold medals
// add a slow band of light crossing now and then (`sheen_on`).

uniform vec3 light : source_color = vec3(1.0);
uniform vec3 mid : source_color = vec3(0.7);
uniform vec3 dark : source_color = vec3(0.3);
uniform float sheen_on = 0.0;

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	float value = dot(picture.rgb, vec3(0.3, 0.59, 0.11));
	value = smoothstep(0.08, 0.92, value);
	vec3 metal = value < 0.5 ? mix(dark, mid, value * 2.0) : mix(mid, light, value * 2.0 - 1.0);
	float sweep = fract(TIME * 0.14) * 3.0 - 1.0;
	float band = smoothstep(0.14, 0.0, abs(UV.x + UV.y * 0.6 - sweep * 1.6));
	metal = mix(metal, vec3(1.0, 0.97, 0.86), band * 0.55 * sheen_on);
	COLOR = vec4(metal, picture.a * COLOR.a);
}
