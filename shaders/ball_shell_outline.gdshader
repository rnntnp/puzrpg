shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.36, 0.62, 0.78, 0.95);
uniform float outline_color_texel_width : hint_range(0.0, 64.0, 0.1) = 4.0;
uniform float outline_total_texel_width : hint_range(0.0, 64.0, 0.1) = 6.0;
uniform float outline_expand_texels : hint_range(0.0, 64.0, 0.1) = 6.0;
uniform bool frozen_enabled = false;
uniform vec4 frozen_outer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float frozen_outer_texel_width : hint_range(0.0, 64.0, 0.1) = 12.0;

void vertex() {
	vec2 expansion_ratio = vec2(1.0) + TEXTURE_PIXEL_SIZE * outline_expand_texels * 2.0;
	VERTEX *= expansion_ratio;
}

void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	float outer_sample = 1.0;
	float total_sample = 1.0;
	float frozen_sample = 1.0;
	for (int index = 0; index < 16; index++) {
		float angle = 6.2831853 * float(index) / 16.0;
		vec2 direction = vec2(cos(angle), sin(angle));
		float outer_alpha = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * outline_color_texel_width).a;
		float total_alpha = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * outline_total_texel_width).a;
		float frozen_alpha = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * frozen_outer_texel_width).a;
		outer_sample = min(outer_sample, outer_alpha);
		total_sample = min(total_sample, total_alpha);
		frozen_sample = min(frozen_sample, frozen_alpha);
	}
	float color_complete_band = clamp(center_alpha - outer_sample, 0.0, 1.0);
	float complete_band = clamp(center_alpha - total_sample, 0.0, 1.0);
	float frozen_outer_band = clamp(center_alpha - frozen_sample, 0.0, 1.0);
	float frozen_band = frozen_enabled ? frozen_outer_band : 0.0;
	float colored_band = color_complete_band;
	if (frozen_enabled) {
		colored_band = max(color_complete_band - frozen_outer_band, 0.0);
	}
	float white_band = max(complete_band - color_complete_band, 0.0);
	float band_sum = max(colored_band + white_band + frozen_band, 0.0001);
	vec3 final_color = (
		outline_color.rgb * colored_band
		+ vec3(1.0) * white_band
		+ frozen_outer_color.rgb * frozen_band
	) / band_sum;
	float final_alpha = clamp(
		colored_band * outline_color.a
		+ white_band * 0.92
		+ frozen_band * frozen_outer_color.a,
		0.0,
		1.0
	);
	COLOR = vec4(final_color, final_alpha);
}
