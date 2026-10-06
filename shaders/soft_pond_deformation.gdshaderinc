uniform vec4 soft_deformation = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec2 soft_offset = vec2(0.0);
uniform vec4 soft_basis = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 soft_inverse = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec2 soft_origin = vec2(0.0);
uniform int soft_point_count = 0;
uniform vec2 soft_rest_points[16];
uniform vec2 soft_point_offsets[16];

vec2 soft_surface_vertex(vec2 vertex) {
	mat2 basis = mat2(soft_basis.xy, soft_basis.zw);
	mat2 inverse_basis = mat2(soft_inverse.xy, soft_inverse.zw);
	mat2 deformation = mat2(soft_deformation.xy, soft_deformation.zw);
	vec2 point = basis * vertex + soft_origin;
	vec2 deformed = deformation * point + soft_offset;
	if (soft_point_count > 0) {
		vec2 rest_center = vec2(0.0);
		vec2 center_offset = vec2(0.0);
		for (int i = 0; i < 16; i++) {
			if (i >= soft_point_count) { break; }
			rest_center += soft_rest_points[i] / float(soft_point_count);
			center_offset += soft_point_offsets[i] / float(soft_point_count);
		}
		vec2 displacement = center_offset;
		vec2 relative = point - rest_center;
		for (int i = 0; i < 16; i++) {
			if (i >= soft_point_count) { break; }
			int j = (i + 1) % soft_point_count;
			vec2 a = soft_rest_points[i] - rest_center;
			vec2 b = soft_rest_points[j] - rest_center;
			float determinant = a.x * b.y - a.y * b.x;
			if (abs(determinant) < 0.000001) { continue; }
			float x = (relative.x * b.y - relative.y * b.x) / determinant;
			float y = (a.x * relative.y - a.y * relative.x) / determinant;
			if (x >= -0.00001 && y >= -0.00001) {
				displacement = (1.0 - x - y) * center_offset + x * soft_point_offsets[i] + y * soft_point_offsets[j];
				break;
			}
		}
		deformed = point + displacement;
	}
	return vertex + inverse_basis * (deformed - point);
}
