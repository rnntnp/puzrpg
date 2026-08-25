shader_type canvas_item;
render_mode unshaded;

uniform vec4 wave_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float expansion_texels : hint_range(0.0, 128.0, 0.1) = 36.0;
uniform float start_radius : hint_range(0.1, 0.5, 0.001) = 0.42;
uniform float wave_width : hint_range(0.001, 0.1, 0.001) = 0.012;
uniform float cycle_seconds : hint_range(0.2, 3.0, 0.05) = 0.85;

void vertex() {
	vec2 expansion_ratio = vec2(1.0) + TEXTURE_PIXEL_SIZE * expansion_texels * 2.0;
	VERTEX *= expansion_ratio;
}

float wave_alpha(float phase, float distance_from_center) {
	float current_radius = mix(start_radius, 0.5, phase);
	float ring = 1.0 - smoothstep(wave_width, wave_width * 1.8, abs(distance_from_center - current_radius));
	return ring * (1.0 - phase);
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_from_center = length(centered_uv);
	float base_phase = fract(TIME / max(cycle_seconds, 0.01));
	float first_wave = wave_alpha(base_phase, distance_from_center);
	float second_wave = wave_alpha(fract(base_phase + 0.5), distance_from_center);
	float alpha = max(first_wave, second_wave) * wave_color.a;
	COLOR = vec4(wave_color.rgb, alpha);
}
