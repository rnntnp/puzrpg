shader_type canvas_item;
render_mode unshaded;

uniform vec4 dash_color : source_color = vec4(1.0, 0.88, 0.29, 1.0);
uniform vec4 dash_secondary_color : source_color = vec4(1.0, 0.25, 0.5, 1.0);
uniform float expansion_texels : hint_range(0.0, 96.0, 0.1) = 14.0;
uniform float dash_width_texels : hint_range(0.0, 32.0, 0.1) = 5.0;
uniform float dash_count : hint_range(4.0, 32.0, 1.0) = 14.0;
uniform float dash_fill : hint_range(0.1, 0.9, 0.01) = 0.52;
uniform float rotations_per_second : hint_range(-2.0, 2.0, 0.05) = 0.22;
uniform float color_cycles_per_second : hint_range(0.0, 4.0, 0.05) = 0.55;

void vertex() {
	vec2 expansion_ratio = vec2(1.0) + TEXTURE_PIXEL_SIZE * expansion_texels * 2.0;
	VERTEX *= expansion_ratio;
}

void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	float inner_sample = 1.0;
	for (int index = 0; index < 16; index++) {
		float angle = 6.2831853 * float(index) / 16.0;
		vec2 direction = vec2(cos(angle), sin(angle));
		float sampled_alpha = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * dash_width_texels).a;
		inner_sample = min(inner_sample, sampled_alpha);
	}
	float outline_band = clamp(center_alpha - inner_sample, 0.0, 1.0);
	vec2 centered_uv = UV - vec2(0.5);
	float contour_angle = atan(centered_uv.y, centered_uv.x) / 6.2831853 + 0.5;
	float moving_phase = fract(contour_angle * dash_count - TIME * rotations_per_second * dash_count);
	float dash_mask = 1.0 - step(dash_fill, moving_phase);
	float color_wave = 0.5 + 0.5 * sin(
		6.2831853 * (contour_angle * 2.0 - TIME * color_cycles_per_second)
	);
	vec4 animated_color = mix(dash_color, dash_secondary_color, color_wave);
	COLOR = vec4(animated_color.rgb, animated_color.a * outline_band * dash_mask);
}
