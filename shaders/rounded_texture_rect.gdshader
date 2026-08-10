shader_type canvas_item;

uniform float corner_radius_px : hint_range(0.0, 96.0, 1.0) = 28.0;
uniform float edge_softness_px : hint_range(0.5, 4.0, 0.1) = 1.5;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 size_px = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 centered_px = abs(UV * size_px - size_px * 0.5);
	vec2 box_distance = centered_px - (size_px * 0.5 - vec2(corner_radius_px));
	float distance_px = length(max(box_distance, vec2(0.0)))
		+ min(max(box_distance.x, box_distance.y), 0.0)
		- corner_radius_px;
	color.a *= 1.0 - smoothstep(-edge_softness_px, edge_softness_px, distance_px);
	COLOR = color;
}
