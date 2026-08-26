shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mask_texture : source_color, filter_linear_mipmap;
// 마스크 대상 Sprite2D는 그대로 두고, 셸 외곽의 로컬 변환만 마스크 UV에 반영한다.
uniform vec2 mask_offset_pixels = vec2(0.0);
uniform float mask_rotation = 0.0;
uniform vec2 mask_sprite_scale = vec2(1.0);

void fragment() {
	// Preserve Sprite2D.self_modulate/modulate so mechanic visuals can tint
	// the masked axolotl itself instead of only affecting shell overlays.
	vec4 sprite_color = texture(TEXTURE, UV) * COLOR;
	vec2 mask_size = vec2(textureSize(mask_texture, 0));
	vec2 centered_pixel = (UV - vec2(0.5)) * mask_size * mask_sprite_scale + mask_offset_pixels;
	float cosine = cos(-mask_rotation);
	float sine = sin(-mask_rotation);
	vec2 mask_pixel = vec2(
		centered_pixel.x * cosine - centered_pixel.y * sine,
		centered_pixel.x * sine + centered_pixel.y * cosine
	);
	vec2 mask_uv = mask_pixel / mask_size + vec2(0.5);
	vec2 inside_minimum = step(vec2(0.0), mask_uv);
	vec2 inside_maximum = step(mask_uv, vec2(1.0));
	float inside_mask = inside_minimum.x * inside_minimum.y * inside_maximum.x * inside_maximum.y;
	float mask_alpha = texture(mask_texture, clamp(mask_uv, vec2(0.0), vec2(1.0))).a * inside_mask;
	sprite_color.a *= mask_alpha;
	COLOR = sprite_color;
}
