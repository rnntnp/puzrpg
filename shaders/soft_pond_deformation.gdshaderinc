uniform vec4 soft_deformation = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec2 soft_offset = vec2(0.0);
uniform vec4 soft_basis = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 soft_inverse = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec2 soft_origin = vec2(0.0);
uniform int soft_point_count = 0;
uniform vec2 soft_rest_points[16];
uniform vec2 soft_point_offsets[16];
uniform float soft_interior_gain = 1.0;
uniform float soft_strain_weight = 1.0;
uniform float soft_center_radius = 1.0;
uniform vec2 soft_vertical_gain = vec2(1.0);

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
		if (soft_interior_gain > 1.0) {
			// Preserve the full original deformation and add a smooth LOCAL
			// amplification, rather than replacing it with one average strain.
			float radial = length(relative) / max(soft_center_radius, 0.001);
			float blend = 1.0 - smoothstep(0.1, 1.0, radial);
			float xx = 0.0;
			float xy = 0.0;
			float yy = 0.0;
			vec2 bx = vec2(0.0);
			vec2 by = vec2(0.0);
			float range_squared = max(soft_center_radius * soft_center_radius * 0.6, 0.001);
			for (int i = 0; i < 16; i++) {
				if (i >= soft_point_count) { break; }
				vec2 p = soft_rest_points[i] - rest_center;
				vec2 u = soft_point_offsets[i] - center_offset;
				float weight = exp(-dot(p - relative, p - relative) / range_squared);
				xx += weight * p.x * p.x;
				xy += weight * p.x * p.y;
				yy += weight * p.y * p.y;
				bx += weight * u * p.x;
				by += weight * u * p.y;
			}
			float determinant = max(xx * yy - xy * xy, 0.0001);
			vec2 column_x = (bx * yy - by * xy) / determinant;
			vec2 column_y = (by * xx - bx * xy) / determinant;
			vec2 local_strain = column_x * relative.x + column_y * relative.y;
			// Follow the character's own up/down axis, including ball rotation.
			float vertical = dot(point - soft_origin, normalize(basis[1])) / max(soft_center_radius, 0.001);
			float cheek_weight = mix(soft_vertical_gain.x, soft_vertical_gain.y, smoothstep(-0.45, 0.45, vertical));
			vec2 extra = local_strain * (soft_interior_gain - 1.0) * blend * cheek_weight;
			// A generous, continuous soft limit: no early eigenvalue plateau.
			float limit = max(soft_center_radius * 1.25, 0.001);
			extra *= inversesqrt(1.0 + dot(extra, extra) / (limit * limit));
			displacement += extra;
		}
		deformed = point + center_offset + (displacement - center_offset) * soft_strain_weight;
	}
	return vertex + inverse_basis * (deformed - point);
}
