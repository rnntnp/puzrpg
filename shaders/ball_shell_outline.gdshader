shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.36, 0.62, 0.78, 0.9);
uniform float outline_texel_width : hint_range(0.0, 32.0, 0.1) = 4.0;
uniform vec2 shell_center_texels = vec2(196.0, 210.0);
uniform vec2 shell_radius_texels = vec2(179.0, 187.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 texel_position = UV / TEXTURE_PIXEL_SIZE;
	vec2 ellipse_position = (texel_position - shell_center_texels) / shell_radius_texels;
	float radial_distance = length(ellipse_position);
	float average_radius = (shell_radius_texels.x + shell_radius_texels.y) * 0.5;
	float boundary_distance = abs(radial_distance - 1.0) * average_radius;
	float half_width = outline_texel_width * 0.5;
	float outline_alpha = 1.0 - smoothstep(max(half_width - 1.0, 0.0), half_width + 1.0, boundary_distance);
	outline_alpha *= outline_color.a;
	vec4 outline = vec4(outline_color.rgb, outline_alpha * tint.a);
	COLOR = outline;
}
