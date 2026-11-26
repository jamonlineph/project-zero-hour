// Terrain material with fog of war (P1-27). FogOfWar feeds `fog_texture`:
// one texel per 8 m vision cell, red = 0 unexplored, 0.5 explored, 1 visible.
// Linear filtering softens the cell edges.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(0.36, 0.42, 0.28, 1.0);
uniform float roughness_value = 1.0;
uniform sampler2D fog_texture : filter_linear, repeat_disable;
uniform vec2 fog_size = vec2(128.0, 128.0);   // meters covered by the texture
uniform float explored_brightness = 0.45;
uniform float unexplored_brightness = 0.04;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = texture(fog_texture, world_pos.xz / fog_size).r;
	float light = f < 0.5
		? mix(unexplored_brightness, explored_brightness, f * 2.0)
		: mix(explored_brightness, 1.0, (f - 0.5) * 2.0);
	ALBEDO = albedo.rgb * light;
	ROUGHNESS = roughness_value;
}
