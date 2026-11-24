shader_type canvas_item;
render_mode unshaded, blend_add;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	// Smooth integral of the former twelve translucent discs. One quad;
	// per-ball tint and strength are supplied through vertex COLOR.
	float t = clamp((1.0 - radius) / 0.40588235, 0.0, 1.0);
	float falloff = 12.0 * (0.006 * t + 0.0096 * pow(t, 2.5));
	COLOR = vec4(COLOR.rgb, COLOR.a * falloff);
}
