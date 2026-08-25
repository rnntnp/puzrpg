shader_type canvas_item;

uniform vec4 matte_color : source_color = vec4(0.66, 0.88, 0.96, 0.8);
uniform vec4 sheen_color : source_color = vec4(0.95, 0.99, 1.0, 0.8);
uniform float cycle_seconds : hint_range(0.4, 4.0, 0.05) = 1.5;
uniform float band_width : hint_range(0.04, 0.5, 0.01) = 0.18;
uniform float band_softness : hint_range(0.005, 0.2, 0.005) = 0.06;
uniform float diagonal_slope : hint_range(-2.0, 2.0, 0.05) = 0.65;

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	float diagonal = UV.x + UV.y * diagonal_slope;
	float travel_range = 1.0 + abs(diagonal_slope) + band_width * 2.0;
	float phase = mod(TIME / max(cycle_seconds, 0.01), 1.0);
	float center = -band_width + phase * travel_range;
	float distance_to_band = abs(diagonal - center);
	float band = 1.0 - smoothstep(band_width, band_width + band_softness, distance_to_band);
	vec4 color = mix(matte_color, sheen_color, band);
	COLOR = vec4(color.rgb, color.a * mask);
}
