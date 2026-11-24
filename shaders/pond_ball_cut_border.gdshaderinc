uniform bool ball_cut_border_enabled = false;
uniform vec4 ball_cut_color : source_color = vec4(0.4, 0.7, 0.9, 0.95);
uniform float ball_cut_color_width = 1.5;
uniform float ball_cut_white_width = 1.0;
uniform float ball_cut_depth_ratio = 3.0;

float ball_front_sample(vec2 uv, float own_priority) {
	vec4 owner = texture(ball_ownership, uv);
	float front_priority = dot(owner.rgb, vec3(1.0, 255.0, 65025.0));
	return step(0.5, owner.a) * step(own_priority + 0.002, front_priority);
}

float ball_front_coverage(vec2 uv, float own_priority) {
	// Interpolate decoded coverage, never the encoded ball IDs themselves.
	vec2 size = vec2(textureSize(ball_ownership, 0));
	vec2 pixel = uv * size - vec2(0.5);
	vec2 base = (floor(pixel) + vec2(0.5)) / size;
	vec2 fraction = fract(pixel);
	vec2 texel = vec2(1.0) / size;
	float a = ball_front_sample(base, own_priority);
	float b = ball_front_sample(base + vec2(texel.x, 0.0), own_priority);
	float c = ball_front_sample(base + vec2(0.0, texel.y), own_priority);
	float d = ball_front_sample(base + texel, own_priority);
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

float ball_hidden_sample(sampler2D shell_texture, vec2 shell_uv, vec2 screen_uv, float own_priority) {
	if (any(lessThan(shell_uv, vec2(0.0))) || any(greaterThan(shell_uv, vec2(1.0)))) { return 0.0; }
	return step(0.5, texture(shell_texture, shell_uv).a) * ball_front_sample(screen_uv, own_priority);
}

vec4 ball_cut_border(vec2 screen_uv, vec2 pixel_size, float original_color_band,
		sampler2D shell_texture, vec2 shell_uv, vec2 uv_dx, vec2 uv_dy) {
	vec4 center = texture(ball_ownership, screen_uv);
	if (center.a < 0.5 || distance(center.rgb, ball_owner) > 0.002) {
		return vec4(0.0);
	}
	float colored = 0.0;
	float total = 0.0;
	vec3 priority_weights = vec3(1.0, 255.0, 65025.0);
	float own_priority = dot(ball_owner, priority_weights);
	float border_width = ball_cut_color_width + ball_cut_white_width;
	float full_depth = border_width * ball_cut_depth_ratio;
	for (int i = 0; i < 16; i++) {
		float angle = 6.2831853 * float(i) / 16.0;
		vec2 unit_direction = vec2(cos(angle), sin(angle));
		vec2 direction = unit_direction * pixel_size;
		float far_coverage = ball_front_coverage(screen_uv + direction * border_width, own_priority);
		if (far_coverage <= 0.0) { continue; }
		float fade = 1.0;
		if (full_depth > 0.0001) {
			// Locate the cut, then measure how far the hidden shell continues.
			float cut_low = 0.0;
			float cut_high = border_width;
			for (int search = 0; search < 5; search++) {
				float middle = (cut_low + cut_high) * 0.5;
				if (ball_front_sample(screen_uv + direction * middle, own_priority) > 0.5) { cut_high = middle; }
				else { cut_low = middle; }
			}
			vec2 uv_direction = uv_dx * unit_direction.x + uv_dy * unit_direction.y;
			float probe = cut_high + full_depth;
			if (ball_hidden_sample(shell_texture, shell_uv + uv_direction * probe, screen_uv + direction * probe, own_priority) < 0.5) {
				float low = 0.0;
				float high = full_depth;
				for (int search = 0; search < 7; search++) {
					float middle = (low + high) * 0.5;
					probe = cut_high + middle;
					if (ball_hidden_sample(shell_texture, shell_uv + uv_direction * probe, screen_uv + direction * probe, own_priority) > 0.5) { low = middle; }
					else { high = middle; }
				}
				float depth = (low + high) * 0.5;
				// Fade over a fixed half-border width below the slider threshold.
				float fade_span = min(border_width * 0.5, full_depth);
				fade = clamp((depth - (full_depth - fade_span)) / max(fade_span, 0.0001), 0.0, 1.0);
			}
		}
		// Only a higher-priority (front) silhouette may cut this ball.
		// The front ball must never draw a second seam toward a rear neighbor.
		colored = max(colored, ball_front_coverage(screen_uv + direction * ball_cut_color_width, own_priority) * fade);
		total = max(total, far_coverage * fade);
	}
	// Use the shell shader's exact original colored band, including its authored
	// texel width and alpha coverage, so the new white seam cannot paint over it.
	float white = max(total - colored, 0.0) * (1.0 - clamp(original_color_band, 0.0, 1.0));
	float color_alpha = colored * ball_cut_color.a;
	float white_alpha = white * 0.92;
	float alpha = color_alpha + white_alpha;
	vec3 rgb = (ball_cut_color.rgb * color_alpha + vec3(white_alpha)) / max(alpha, 0.0001);
	return vec4(rgb, alpha);
}
