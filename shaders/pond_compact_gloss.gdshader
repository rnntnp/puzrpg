shader_type canvas_item;
render_mode unshaded;

// An anisotropic normal lobe calibrated to the former 96 x 32 ellipse.
// No authored gloss pixels are sampled. The virtual curved surface reflects
// a broad light toward an orthographic camera.
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 surface_tilt = vec2(0.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(96.0 / 43.0, 32.0 / 11.0);
	vec3 light = normalize(vec3(-0.6, -0.8, 0.9));
	vec3 half_vector = normalize(light + vec3(0.0, 0.0, 1.0));
	vec3 tangent = normalize(vec3(half_vector.z, 0.0, -half_vector.x));
	vec3 bitangent = cross(half_vector, tangent);
	// Tangent-space curvature keeps both ellipse axes symmetric around the
	// specular maximum; cage pressure tilts this virtual surface.
	vec2 slope = p * 0.12 + surface_tilt;
	vec3 normal = normalize(half_vector + tangent * slope.x + bitangent * slope.y);
	float alignment = max(dot(normal, half_vector), 0.0);
	float specular = pow(alignment, 32.0);
	float footprint = 1.0 - smoothstep(0.72, 1.0, length(p));
	float coverage = smoothstep(0.77, 0.89, specular) * footprint;
	COLOR = vec4(vec3(1.0), coverage * opacity * COLOR.a);
}
