shader_type canvas_item;

uniform sampler2D mask_texture : source_color, filter_linear;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.001;
uniform vec2 visible_uv_offset = vec2(0.0);
uniform vec2 visible_uv_scale = vec2(1.0);
uniform vec2 texture_uv_offset = vec2(0.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV + texture_uv_offset);
	vec2 mask_uv = (UV - visible_uv_offset) / visible_uv_scale;
	if (any(lessThan(mask_uv, vec2(0.0))) || any(greaterThan(mask_uv, vec2(1.0)))) {
		discard;
	}
	float mask_alpha = texture(mask_texture, mask_uv).a;

	if (mask_alpha <= alpha_cutoff) {
		discard;
	}

	tex_color.a *= mask_alpha;
	COLOR = tex_color;
}
