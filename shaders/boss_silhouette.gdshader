shader_type canvas_item;

uniform vec4 shadow_top : source_color = vec4(0.09, 0.015, 0.14, 1.0);
uniform vec4 shadow_bottom : source_color = vec4(0.005, 0.003, 0.015, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 32.0, 0.5) = 4.2;

varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	float alpha = texture_color.a;
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	float vertical = smoothstep(0.05, 0.95, UV.y);
	vec3 shadow = mix(shadow_top.rgb, shadow_bottom.rgb, vertical);
	if (alpha > 0.001) {
		COLOR = vec4(shadow, alpha * sprite_modulate.a);
	} else {
		COLOR = vec4(outline_color.rgb, outline_color.a * nearby_alpha * sprite_modulate.a);
	}
}
