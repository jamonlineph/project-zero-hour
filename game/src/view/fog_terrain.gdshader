// Terrain material with fog of war (P1-27). FogOfWar feeds `fog_texture`:
// one texel per 8 m vision cell, red = 0 unexplored, 0.5 explored, 1 visible.
// Linear filtering softens the cell edges.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(0.36, 0.42, 0.28, 1.0);
uniform bool use_vertex_color = false;   // TerrainView colors by slope and height
uniform float roughness_value = 1.0;
uniform sampler2D fog_texture : filter_linear, repeat_disable;
uniform vec2 fog_size = vec2(128.0, 128.0);   // meters covered by the texture
uniform float explored_brightness = 0.45;
uniform float unexplored_brightness = 0.04;
// Ground detail (P3-23d): procedural light and dark grain at two scales, so
// the ground reads as earth and grass rather than flat paint. 0 = off (units,
// buildings and props).
uniform float detail_strength = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float f = texture(fog_texture, world_pos.xz / fog_size).r;
	float light = f < 0.5
		? mix(unexplored_brightness, explored_brightness, f * 2.0)
		: mix(explored_brightness, 1.0, (f - 0.5) * 2.0);
	vec3 base = use_vertex_color ? COLOR.rgb : albedo.rgb;
	if (detail_strength > 0.0) {
		float patches = value_noise(world_pos.xz * 0.12) - 0.5;   // ~8 m patches
		float grain = value_noise(world_pos.xz * 1.7) - 0.5;      // ~0.6 m grain
		base *= 1.0 + detail_strength * (0.16 * patches + 0.10 * grain);
	}
	ALBEDO = base * light;
	ROUGHNESS = roughness_value;
}
