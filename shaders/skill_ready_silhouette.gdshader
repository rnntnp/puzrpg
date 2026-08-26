shader_type canvas_item;
render_mode unshaded;

// The node itself has no icon texture. This sampler is used only as an alpha
// mask, so a failed/disabled shader can never reveal a scaled copy of the icon.
uniform sampler2D skill_texture : filter_linear, repeat_disable;
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.18, 1.0);
uniform float animation_speed : hint_range(0.1, 3.0, 0.05) = 0.72;
uniform float maximum_distance : hint_range(0.02, 0.24, 0.005) = 0.16;
uniform float band_width : hint_range(0.005, 0.06, 0.001) = 0.022;
uniform float padding_ratio : hint_range(0.05, 0.35, 0.005) = 0.22;
uniform bool hovered = false;

float icon_alpha(vec2 icon_uv) {
	if (icon_uv.x < 0.0 || icon_uv.x > 1.0 || icon_uv.y < 0.0 || icon_uv.y > 1.0) {
		return 0.0;
	}
	return texture(skill_texture, icon_uv).a;
}

float radial_sample(vec2 icon_uv, float distance_from_shape) {
	float sampled_alpha = 0.0;
	for (int index = 0; index < 32; index++) {
		float angle = 6.2831853 * float(index) / 32.0;
		vec2 direction = vec2(cos(angle), sin(angle));
		sampled_alpha = max(sampled_alpha, icon_alpha(icon_uv + direction * distance_from_shape));
	}
	return sampled_alpha;
}

float outline_wave(vec2 icon_uv, float phase, float distance_limit) {
	float eased_phase = 1.0 - pow(1.0 - phase, 2.0);
	float distance_from_shape = mix(0.012, distance_limit, eased_phase);
	float outer_sample = radial_sample(icon_uv, distance_from_shape);
	float inner_sample = radial_sample(icon_uv, max(distance_from_shape - band_width, 0.001));
	float band = max(outer_sample - inner_sample, 0.0);
	float lifetime_fade = sin(phase * 3.14159265);
	return band * lifetime_fade;
}

void fragment() {
	vec2 icon_uv = (UV - vec2(padding_ratio)) / (1.0 - padding_ratio * 2.0);
	float center_alpha = icon_alpha(icon_uv);
	float distance_limit = maximum_distance;
	if (hovered) {
		distance_limit *= 1.12;
	}
	float base_phase = fract(TIME * animation_speed);
	float wave_alpha = 0.0;
	wave_alpha = max(wave_alpha, outline_wave(icon_uv, base_phase, distance_limit));
	wave_alpha = max(wave_alpha, outline_wave(icon_uv, fract(base_phase + 0.3333333), distance_limit));
	wave_alpha = max(wave_alpha, outline_wave(icon_uv, fract(base_phase + 0.6666667), distance_limit));
	// Never draw over the original skill silhouette. Only outward-moving bands
	// remain, while the normal icon is rendered once by the button itself.
	wave_alpha *= 1.0 - smoothstep(0.0, 0.08, center_alpha);
	COLOR = vec4(glow_color.rgb, glow_color.a * clamp(wave_alpha * 1.18, 0.0, 1.0));
}
