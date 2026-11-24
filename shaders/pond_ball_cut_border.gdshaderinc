uniform bool ball_cut_border_enabled = false;
uniform vec4 ball_cut_color : source_color = vec4(0.4, 0.7, 0.9, 0.95);
uniform float ball_cut_color_width = 1.5;
uniform float ball_cut_white_width = 1.0;
uniform float ball_cut_depth_ratio = 3.0;
uniform bool ball_cut_metric_correct = false;
uniform float ball_cut_color_texels = 4.0;
uniform float ball_cut_total_texels = 6.0;
uniform bool ball_cut_fixed_width = false;
uniform vec2 ball_cut_screen_widths = vec2(4.0,6.0);
uniform bool ball_cut_sdf_enabled = false;
uniform sampler2D ball_cut_sdf : filter_nearest, repeat_disable;

vec4 ball_cut_from_sdf(vec2 uv, vec2 screen_pixel, float original_color_band) {
	vec4 own=texture(ball_ownership,uv);
	if (own.a<0.5 || distance(own.rgb,ball_owner)>0.002) {return vec4(0.0);}
	vec2 size=vec2(textureSize(ball_cut_sdf,0));
	vec2 at=uv*size-vec2(0.5);
	vec2 base=floor(at);
	float nearest=100000.0;
	// Decode points before measuring distance. Interpolating packed IDs or
	// coordinates would invent false boundaries at owner/invalid transitions.
	for (int y=0;y<=1;y++) {
		for (int x=0;x<=1;x++) {
			vec2 q=(base+vec2(float(x),float(y))+vec2(0.5))/size;
			vec4 packed=floor(texture(ball_cut_sdf,q)*255.0+0.5);
			vec2 seed=vec2(packed.x*256.0+packed.y,packed.z*256.0+packed.w)-vec2(1.0);
			if (seed.x<0.0 || seed.y<0.0) {continue;}
			vec2 seed_uv=(seed+vec2(0.5))/size;
			vec4 seed_owner=texture(ball_ownership,seed_uv);
			if (seed_owner.a<0.5 || distance(seed_owner.rgb,ball_owner)>0.002) {continue;}
			float d=length((uv-seed_uv)/screen_pixel)+0.5/(size.x*screen_pixel.x);
			nearest=min(nearest,d);
		}
	}
	float colored=1.0-smoothstep(ball_cut_screen_widths.x-0.5,ball_cut_screen_widths.x+0.5,nearest);
	float total=1.0-smoothstep(ball_cut_screen_widths.y-0.5,ball_cut_screen_widths.y+0.5,nearest);
	float white=max(total-colored,0.0)*(1.0-clamp(original_color_band,0.0,1.0));
	float ca=colored*ball_cut_color.a;
	float wa=white*0.92;
	float alpha=ca+wa;
	return vec4((ball_cut_color.rgb*ca+vec3(wa))/max(alpha,0.0001),alpha);
}
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

vec4 ball_cut_border_legacy(vec2 screen_uv, vec2 pixel_size, float original_color_band,
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

float ball_cut_pixel_metric(vec2 normal, vec2 tex_dx, vec2 tex_dy) {
	float determinant = tex_dx.x * tex_dy.y - tex_dy.x * tex_dx.y;
	if (abs(determinant) < 0.000001) { return 1.0; }
	// Inverse UV Jacobian: includes expanded vertices, rotation and the actual
	// deformation at this pixel. Support distance in the cut's screen normal.
	vec2 screen_x = vec2(tex_dy.y, -tex_dx.y) / determinant;
	vec2 screen_y = vec2(-tex_dy.x, tex_dx.x) / determinant;
	return length(vec2(dot(screen_x, normal), dot(screen_y, normal)));
}

float ball_cut_hidden_coverage(sampler2D shell_texture, vec2 shell_uv, vec2 screen_uv, float own_priority) {
	if (any(lessThan(shell_uv, vec2(0.0))) || any(greaterThan(shell_uv, vec2(1.0)))) { return 0.0; }
	return smoothstep(0.25,0.75,texture(shell_texture,shell_uv).a) * ball_front_coverage(screen_uv,own_priority);
}

float ball_cut_first_crossing(vec2 screen_uv, vec2 pixel_size, vec2 direction,
		float reach, float own_priority) {
	// Test every half screen pixel, not just the far endpoint. A thin covered
	// interval can enter AND exit inside the stroke radius.
	float previous=0.0;
	for (int probe=1;probe<=64;probe++) {
		float distance_from_pixel=min(float(probe)*0.5,reach);
		if (ball_front_coverage(screen_uv+direction*pixel_size*distance_from_pixel,own_priority)>=0.5) {
			float low=previous;float high=distance_from_pixel;
			for (int search=0;search<4;search++) {
				float middle=(low+high)*0.5;
				if (ball_front_coverage(screen_uv+direction*pixel_size*middle,own_priority)>=0.5) {high=middle;}
				else {low=middle;}
			}
			return high;
		}
		if (distance_from_pixel>=reach) {break;}
		previous=distance_from_pixel;
	}
	return 100000.0;
}

vec4 ball_cut_border_metric(vec2 screen_uv, vec2 pixel_size, float original_color_band,
		sampler2D shell_texture, vec2 shell_uv, vec2 uv_dx, vec2 uv_dy) {
	vec4 center = texture(ball_ownership,screen_uv);
	if (center.a < 0.5 || distance(center.rgb,ball_owner) > 0.002) { return vec4(0.0); }
	float own_priority = dot(ball_owner,vec3(1.0,255.0,65025.0));
	vec2 texture_size = vec2(textureSize(shell_texture,0));
	vec2 tex_dx = uv_dx * texture_size;
	vec2 tex_dy = uv_dy * texture_size;
	vec2 normal = vec2(1.0,0.0);
	float nearest = 100000.0;
	// Find the nearest cut, instead of choosing different rays for the color,
	// white band and fade. That previously made the seam appear narrower.
	for (int i=0;i<24;i++) {
		float angle = 6.2831853 * float(i)/24.0;
		vec2 direction = vec2(cos(angle),sin(angle));
		float reach = (ball_cut_fixed_width ? ball_cut_screen_widths.y : ball_cut_total_texels * ball_cut_pixel_metric(direction,tex_dx,tex_dy)) + 1.0;
		float high=ball_cut_first_crossing(screen_uv,pixel_size,direction,min(reach,nearest),own_priority);
		if (high<nearest) {nearest=high;normal=direction;}
	}
	if (nearest>99999.0) {return vec4(0.0);}
	vec2 edge = screen_uv+normal*pixel_size*nearest;
	vec2 gradient = vec2(
		ball_front_coverage(edge+vec2(pixel_size.x,0.0),own_priority)-ball_front_coverage(edge-vec2(pixel_size.x,0.0),own_priority),
		ball_front_coverage(edge+vec2(0.0,pixel_size.y),own_priority)-ball_front_coverage(edge-vec2(0.0,pixel_size.y),own_priority));
	if (dot(gradient,gradient)>0.0001) {
		vec2 refined = normalize(gradient);
		float reach = (ball_cut_fixed_width ? ball_cut_screen_widths.y : ball_cut_total_texels*ball_cut_pixel_metric(refined,tex_dx,tex_dy))+1.0;
		float high=ball_cut_first_crossing(screen_uv,pixel_size,refined,min(reach,nearest),own_priority);
		if (high<nearest) {normal=refined;nearest=high;}
	}
	float metric = ball_cut_pixel_metric(normal,tex_dx,tex_dy);
	float color_width = max(0.01,ball_cut_color_texels*metric);
	float total_width = max(color_width,ball_cut_total_texels*metric);
	if (ball_cut_fixed_width) {
		color_width=max(0.01,ball_cut_screen_widths.x);
		total_width=max(color_width,ball_cut_screen_widths.y);
	}
	float full_depth = total_width*ball_cut_depth_ratio;
	float hidden_depth = 0.0;
	vec2 uv_direction = uv_dx*normal.x+uv_dy*normal.y;
	float fade_span=min(total_width*0.5,full_depth);
	// Anchor opacity at the cut, shared by both stroke bands. A normal-only
	// probe underestimates broad, shallow overlaps on small curved shells.
	vec2 cut_screen=screen_uv+normal*pixel_size*(nearest+0.5);
	vec2 cut_uv=shell_uv+uv_direction*(nearest+0.5);
	for (int direction=0;direction<9;direction++) {
		float step_index=floor(float(direction+1)*0.5);
		float angle=min(step_index*0.392699082,1.431169986);
		if (direction%2==0) {angle=-angle;}
		vec2 ray=normal*cos(angle)+vec2(-normal.y,normal.x)*sin(angle);
		vec2 ray_uv=uv_dx*ray.x+uv_dy*ray.y;
		// Partial AA coverage only discounts its own interval. Carrying the
		// smallest fractional value forward caps the ENTIRE ray at the edge
		// sample, incorrectly erasing the deepest part of a contact.
		float depth=0.0;
		float continuity=1.0;
		float stride=full_depth/16.0;
		for (int probe=1;probe<=16;probe++) {
			float distance_from_cut=stride*float(probe);
			float coverage=ball_cut_hidden_coverage(shell_texture,cut_uv+ray_uv*distance_from_cut,cut_screen+ray*pixel_size*distance_from_cut,own_priority);
			// A genuine exit still blocks any later re-entry across a notch.
			continuity=min(continuity,smoothstep(0.0,0.1,coverage));
			depth+=coverage*continuity*stride;
		}
		hidden_depth=max(hidden_depth,depth);
		if (hidden_depth>=full_depth) {break;}
	}
	float fade=full_depth>0.0001?clamp((hidden_depth-(full_depth-fade_span))/max(fade_span,0.0001),0.0,1.0):1.0;
	float colored=1.0-smoothstep(color_width-0.5,color_width+0.5,nearest);
	float total=1.0-smoothstep(total_width-0.5,total_width+0.5,nearest);
	float white=max(total-colored,0.0)*(1.0-clamp(original_color_band,0.0,1.0));
	float color_alpha=colored*fade*ball_cut_color.a;
	float white_alpha=white*fade*0.92;
	float alpha=color_alpha+white_alpha;
	return vec4((ball_cut_color.rgb*color_alpha+vec3(white_alpha))/max(alpha,0.0001),alpha);
}

vec4 ball_cut_border(vec2 screen_uv, vec2 pixel_size, float original_color_band,
		sampler2D shell_texture, vec2 shell_uv, vec2 uv_dx, vec2 uv_dy) {
	if (ball_cut_sdf_enabled) {return ball_cut_from_sdf(screen_uv,pixel_size,original_color_band);}
	if (ball_cut_metric_correct) {return ball_cut_border_metric(screen_uv,pixel_size,original_color_band,shell_texture,shell_uv,uv_dx,uv_dy);}
	return ball_cut_border_legacy(screen_uv,pixel_size,original_color_band,shell_texture,shell_uv,uv_dx,uv_dy);
}
