shader_type canvas_item;
render_mode unshaded;

uniform float effect_clock = 0.0;
varying float primitive_kind;
varying vec2 primitive_extent;
varying float ring_radius;
varying float stroke_half_width;

void vertex() {
	float duration = INSTANCE_CUSTOM.y;
	float t = duration > 0.0 ? clamp((effect_clock - INSTANCE_CUSTOM.x) / duration, 0.0, 1.0) : 1.0;
	float p = 1.0 - (1.0 - t) * (1.0 - t);
	float kind = floor(INSTANCE_CUSTOM.z + 0.001);
	float variant = round(fract(INSTANCE_CUSTOM.z) * 10.0);
	float size = INSTANCE_CUSTOM.w;
	vec2 unit = UV * 2.0 - 1.0;
	vec2 extent = vec2(1.0);
	vec2 offset = vec2(0.0);
	float radius = 0.0;
	float width = 0.0;
	if (kind < 0.5) {
		radius = mix(8.0, 36.0, p) * size;
		extent = vec2(radius + 1.0);
	} else if (kind < 3.5) {
		if (kind < 1.5) { radius = mix(5.0, 48.0, p) * size; width = mix(11.0, 2.0, p); }
		else if (kind < 2.5) { radius = mix(12.0, 72.0, p) * size; width = mix(7.0, 1.5, p); }
		else { radius = mix(18.0, 94.0, p) * size; width = 2.0; }
		extent = vec2(radius + width * 0.5 + 1.0);
	} else {
		float start = mix(5.0, 25.0, p) * size;
		float finish = mix(18.0, 70.0 + variant * 8.0, p) * size;
		if (kind < 4.5) {
			offset.x = (start + finish) * 0.5;
			radius = (finish - start) * 0.5;
			width = mix(5.0, 1.0, p);
			extent = vec2(radius, width * 0.5) + vec2(1.0);
		} else if (kind < 5.5) {
			offset.x = finish;
			radius = mix(4.0, 1.0, p);
			extent = vec2(radius + 1.0);
		} else {
			offset.x = finish;
			extent = vec2(8.0, mix(7.0, 1.5, p) + 1.0);
			width = mix(7.0, 1.5, p);
		}
	}
	primitive_kind = kind;
	primitive_extent = extent;
	ring_radius = radius;
	stroke_half_width = width * 0.5;
	VERTEX = unit * extent + offset;
	COLOR.a *= 1.0 - p;
	if (t >= 1.0) { VERTEX = vec2(0.0); COLOR.a = 0.0; }
}

void fragment() {
	vec2 point = (UV * 2.0 - 1.0) * primitive_extent;
	float distance_to_edge;
	if (primitive_kind < 0.5 || (primitive_kind > 4.5 && primitive_kind < 5.5)) {
		distance_to_edge = length(point) - ring_radius;
	} else if (primitive_kind < 3.5) {
		distance_to_edge = abs(length(point) - ring_radius) - stroke_half_width;
	} else if (primitive_kind < 4.5) {
		distance_to_edge = max(abs(point.x) - ring_radius, abs(point.y) - stroke_half_width);
	} else {
		distance_to_edge = (abs(point.x) / 7.0 + abs(point.y) / max(stroke_half_width * 2.0, 0.001) - 1.0) * min(7.0, stroke_half_width * 2.0);
	}
	float aa = max(fwidth(distance_to_edge), 0.001);
	COLOR.a *= 1.0 - smoothstep(-aa, aa, distance_to_edge);
}
