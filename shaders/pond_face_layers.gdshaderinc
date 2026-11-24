uniform int face_layer_role = 0;
uniform vec4 face_atlas_region = vec4(0.0);

vec4 pond_face_layer(vec4 original, sampler2D source_texture, vec2 uv, vec3 tint) {
	if (face_layer_role == 0) { return original; }
	vec2 atlas_size = vec2(textureSize(source_texture, 0));
	vec2 local_uv = (uv * atlas_size - face_atlas_region.xy) / face_atlas_region.zw;
	// Large red/gold atlas cells need a tighter feature region: their cheek
	// silhouette is closer to the eyes than in the smaller sprites.
	// Keep the entire small-sprite family safely inside the head contour,
	// not just the pink cell. Eyes, mouths and cheek blush stay in this region.
	vec2 feature_radius = face_atlas_region.z > 800.0 ? vec2(0.255, 0.16) : vec2(0.28, 0.18);
	float radius = length((local_uv - vec2(0.5, 0.55)) / feature_radius);
	float region = 1.0 - smoothstep(0.85, 1.0, radius);
	if (face_atlas_region.z < 800.0) {
		// Keep wide cheek blush without reopening the outer head contour.
		for (int cheek = 0; cheek < 2; cheek++) {
			vec2 cheek_center = vec2(cheek == 0 ? 0.30 : 0.70, 0.55);
			float cheek_radius = length((local_uv - cheek_center) / vec2(0.075, 0.09));
			region = max(region, 1.0 - smoothstep(0.8, 1.0, cheek_radius));
		}
	}
	// Skin samples above and below the features provide a clean head layer.
	// The residual layer reconstructs the original exactly when poses match.
	vec2 skin_x = vec2(clamp(local_uv.x, 0.42, 0.58), 0.38);
	vec2 top_uv = (face_atlas_region.xy + skin_x * face_atlas_region.zw) / atlas_size;
	vec2 bottom_uv = (face_atlas_region.xy + vec2(skin_x.x, 0.74) * face_atlas_region.zw) / atlas_size;
	vec3 skin = mix(texture(source_texture, top_uv).rgb, texture(source_texture, bottom_uv).rgb, clamp((local_uv.y - 0.38) / 0.36, 0.0, 1.0));
	// The existing sprite shader multiplies its sampled texture by fragment
	// COLOR (which already includes that texture), so match that skin response.
	skin = skin * skin * tint;
	vec3 body = mix(original.rgb, skin, region);
	if (face_layer_role == 1) { return vec4(body, original.a); }
	vec3 dark = max((body - original.rgb) / max(body, vec3(0.001)), vec3(0.0));
	vec3 light = max((original.rgb - body) / max(vec3(1.0) - body, vec3(0.001)), vec3(0.0));
	vec3 difference = max(dark, light);
	float alpha = clamp(max(difference.r, max(difference.g, difference.b)), 0.0, 1.0);
	vec3 features = (original.rgb - body * (1.0 - alpha)) / max(alpha, 0.0001);
	return vec4(clamp(features, vec3(0.0), vec3(1.0)), original.a * alpha);
}
