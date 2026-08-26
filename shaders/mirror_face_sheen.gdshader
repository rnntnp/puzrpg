shader_type canvas_item;

uniform vec2 mirror_center_uv = vec2(0.468, 0.405);
uniform vec2 mirror_radius_uv = vec2(0.235, 0.305);
uniform vec4 sheen_color : source_color = vec4(0.82, 0.97, 1.0, 0.42);
uniform float cycle_seconds : hint_range(0.5, 5.0, 0.05) = 1.8;
uniform float band_width : hint_range(0.02, 0.3, 0.01) = 0.095;
uniform float band_softness : hint_range(0.005, 0.15, 0.005) = 0.045;
uniform float diagonal_slope : hint_range(-2.0, 2.0, 0.05) = 0.72;

void fragment() {
	vec2 ellipse_uv = (UV - mirror_center_uv) / mirror_radius_uv;
	float ellipse = 1.0 - smoothstep(0.90, 1.0, dot(ellipse_uv, ellipse_uv));
	float source_alpha = texture(TEXTURE, UV).a;
	float diagonal = UV.x + UV.y * diagonal_slope;
	float travel_range = 1.0 + abs(diagonal_slope) + band_width * 2.0;
	float phase = mod(TIME / max(cycle_seconds, 0.01), 1.0);
	float center = -band_width + phase * travel_range;
	float distance_to_band = abs(diagonal - center);
	float band = 1.0 - smoothstep(band_width, band_width + band_softness, distance_to_band);
	COLOR = vec4(sheen_color.rgb, sheen_color.a * band * ellipse * source_alpha);
}
