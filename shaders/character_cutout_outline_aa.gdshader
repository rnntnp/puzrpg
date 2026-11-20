shader_type canvas_item;

// Same white, eight-direction silhouette outline as character_white_outline.
// Four samples over the output pixel preserve coverage when shrinking the rig.
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_size : hint_range(0.0, 32.0, 0.5) = 4.0;
varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

vec4 sample_coverage(sampler2D source, vec2 uv, vec2 dx, vec2 dy) {
	vec4 a = texture(source, uv - dx - dy);
	vec4 b = texture(source, uv + dx - dy);
	vec4 c = texture(source, uv - dx + dy);
	vec4 d = texture(source, uv + dx + dy);
	float alpha = (a.a + b.a + c.a + d.a) * 0.25;
	vec3 premultiplied = (a.rgb * a.a + b.rgb * b.a + c.rgb * c.a + d.rgb * d.a) * 0.25;
	return vec4(premultiplied / max(alpha, 0.00001), alpha);
}

void fragment() {
	vec2 dx = dFdx(UV) * 0.25;
	vec2 dy = dFdy(UV) * 0.25;
	vec4 source = sample_coverage(TEXTURE, UV, dx, dy);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_size;
	float nearby = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x != 0 || y != 0) {
				nearby = max(nearby, sample_coverage(TEXTURE, UV + vec2(float(x), float(y)) * step_uv, dx, dy).a);
			}
		}
	}
	float alpha = max(source.a, nearby * outline_color.a);
	vec3 rgb = (source.rgb * sprite_modulate.rgb * source.a
		+ outline_color.rgb * max(0.0, alpha - source.a)) / max(alpha, 0.00001);
	COLOR = vec4(rgb, alpha * sprite_modulate.a);
}
