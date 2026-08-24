shader_type canvas_item;
render_mode unshaded;

uniform sampler2D shell_mask_texture : filter_linear;
uniform float edge_clear_texel_width : hint_range(0.0, 24.0, 0.5) = 9.0;

void fragment() {
	vec4 shadow = texture(TEXTURE, UV) * COLOR;
	vec2 offset = TEXTURE_PIXEL_SIZE * edge_clear_texel_width;
	float inset_alpha = texture(shell_mask_texture, UV).a;
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV + vec2(offset.x, 0.0)).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV - vec2(offset.x, 0.0)).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV + vec2(0.0, offset.y)).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV - vec2(0.0, offset.y)).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV + offset * 0.7071).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV - offset * 0.7071).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV + vec2(offset.x, -offset.y) * 0.7071).a);
	inset_alpha = min(inset_alpha, texture(shell_mask_texture, UV + vec2(-offset.x, offset.y) * 0.7071).a);
	shadow.a *= smoothstep(0.05, 0.65, inset_alpha);
	COLOR = shadow;
}
