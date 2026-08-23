shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 12.0, 0.5) = 4.0;
uniform vec4 outer_fade_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float outer_fade_size : hint_range(0.0, 16.0, 0.5) = 0.0;

varying vec4 sprite_modulate;

void vertex() {
	// Capture the CanvasItem modulation before the default fragment texture path.
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	vec4 sprite_color = texture_color * sprite_modulate;
	vec2 pixel_step = TEXTURE_PIXEL_SIZE * outline_size;

	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel_step.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel_step.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_step.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel_step.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + pixel_step).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel_step).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel_step.x, -pixel_step.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel_step.x, pixel_step.y)).a);

	vec2 near_fade_step = TEXTURE_PIXEL_SIZE * (outline_size + outer_fade_size * 0.35);
	float near_fade_alpha = 0.0;
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(near_fade_step.x, 0.0)).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(-near_fade_step.x, 0.0)).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(0.0, near_fade_step.y)).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(0.0, -near_fade_step.y)).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + near_fade_step).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV - near_fade_step).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(near_fade_step.x, -near_fade_step.y)).a);
	near_fade_alpha = max(near_fade_alpha, texture(TEXTURE, UV + vec2(-near_fade_step.x, near_fade_step.y)).a);

	vec2 middle_fade_step = TEXTURE_PIXEL_SIZE * (outline_size + outer_fade_size * 0.7);
	float middle_fade_alpha = 0.0;
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(middle_fade_step.x, 0.0)).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(-middle_fade_step.x, 0.0)).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(0.0, middle_fade_step.y)).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(0.0, -middle_fade_step.y)).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + middle_fade_step).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV - middle_fade_step).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(middle_fade_step.x, -middle_fade_step.y)).a);
	middle_fade_alpha = max(middle_fade_alpha, texture(TEXTURE, UV + vec2(-middle_fade_step.x, middle_fade_step.y)).a);

	vec2 fade_step = TEXTURE_PIXEL_SIZE * (outline_size + outer_fade_size);
	float outer_nearby_alpha = 0.0;
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(fade_step.x, 0.0)).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(-fade_step.x, 0.0)).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(0.0, fade_step.y)).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -fade_step.y)).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + fade_step).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV - fade_step).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(fade_step.x, -fade_step.y)).a);
	outer_nearby_alpha = max(outer_nearby_alpha, texture(TEXTURE, UV + vec2(-fade_step.x, fade_step.y)).a);

	if (texture_color.a >= 0.999) {
		COLOR = sprite_color;
	} else if (texture_color.a > 0.001) {
		// Resolve antialiased source pixels against white, then make them opaque.
		// CanvasItem alpha modulation remains available for hit/defeat animations.
		vec3 opaque_edge_color = mix(
			outline_color.rgb,
			texture_color.rgb * sprite_modulate.rgb,
			texture_color.a
		);
		COLOR = vec4(opaque_edge_color, sprite_modulate.a);
	} else if (nearby_alpha > 0.001) {
		// White always owns its original outline mask; the dark fade cannot overlap it.
		COLOR = vec4(
			outline_color.rgb,
			outline_color.a * nearby_alpha * sprite_modulate.a
		);
	} else {
		float soft_fade_alpha = max(
			near_fade_alpha * 0.72,
			max(middle_fade_alpha * 0.42, outer_nearby_alpha * 0.18)
		);
		COLOR = vec4(
			outer_fade_color.rgb,
			outer_fade_color.a * soft_fade_alpha * sprite_modulate.a
		);
	}
}
