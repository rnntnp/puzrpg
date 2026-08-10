shader_type canvas_item;

uniform vec4 shadow_top : source_color = vec4(0.09, 0.015, 0.14, 1.0);
uniform vec4 shadow_bottom : source_color = vec4(0.005, 0.003, 0.015, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.12, 0.85, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	vec2 pixel = TEXTURE_PIXEL_SIZE * 3.0;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	float inner_rim = clamp(nearby_alpha - texture(TEXTURE, UV + vec2(pixel.x * 0.55, pixel.y * 0.55)).a, 0.0, 1.0);
	float vertical = smoothstep(0.05, 0.95, UV.y);
	vec3 shadow = mix(shadow_top.rgb, shadow_bottom.rgb, vertical);
	shadow = mix(shadow, rim_color.rgb, inner_rim * rim_strength);
	COLOR = vec4(shadow, alpha);
}
