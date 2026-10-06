shader_type canvas_item;
render_mode unshaded;

uniform vec4 environment_color : source_color = vec4(0.3, 0.65, 0.95, 1.0);
uniform float environment_strength = 0.035;
uniform float highlight_strength = 1.0;
uniform float highlight_radius = 0.20943951;
uniform float highlight_edge = 0.01396263;
uniform float secondary_highlight_strength = 0.75;
uniform float secondary_highlight_radius = 0.13962634;
uniform float secondary_highlight_angle = 3.14159265;
uniform float reflection_strength = 0.60;
uniform float reflection_exposure = 16.0;
uniform float reflection_opacity_limit = 0.45;
uniform float reflection_total_opacity_limit = 0.60;
uniform float reflection_color_brightness = 1.0;
uniform vec2 light_direction = vec2(-0.6, -0.8);
uniform vec2 direction_0 = vec2(1.0, 0.0);
uniform vec2 direction_1 = vec2(1.0, 0.0);
uniform vec2 direction_2 = vec2(1.0, 0.0);
uniform vec4 color_0 : source_color = vec4(0.0);
uniform vec4 color_1 : source_color = vec4(0.0);
uniform vec4 color_2 : source_color = vec4(0.0);
uniform float sharpness_0 = 12.0;
uniform float sharpness_1 = 12.0;
uniform float sharpness_2 = 12.0;
uniform vec2 direction_3 = vec2(1.0, 0.0);
uniform vec4 color_3 : source_color = vec4(0.0);
uniform float sharpness_3 = 12.0;
uniform vec2 direction_4 = vec2(1.0, 0.0);
uniform vec4 color_4 : source_color = vec4(0.0);
uniform float sharpness_4 = 12.0;
uniform vec2 direction_5 = vec2(1.0, 0.0);
uniform vec4 color_5 : source_color = vec4(0.0);
uniform float sharpness_5 = 12.0;
uniform vec2 direction_6 = vec2(1.0, 0.0);
uniform vec4 color_6 : source_color = vec4(0.0);
uniform float sharpness_6 = 12.0;
uniform vec2 direction_7 = vec2(1.0, 0.0);
uniform vec4 color_7 : source_color = vec4(0.0);
uniform float sharpness_7 = 12.0;
uniform vec3 ambient_direction_0 = vec3(0.0, -1.0, 0.25);
uniform vec3 ambient_direction_1 = vec3(1.0, 0.2, 0.30);
uniform vec3 ambient_direction_2 = vec3(-1.0, 0.35, 0.20);
uniform vec4 ambient_color_0 : source_color = vec4(0.55, 0.80, 1.0, 0.16);
uniform vec4 ambient_color_1 : source_color = vec4(1.0, 0.82, 0.58, 0.10);
uniform vec4 ambient_color_2 : source_color = vec4(0.70, 0.60, 1.0, 0.12);
varying vec3 surface_normal;
uniform sampler2D surface_normal_texture : filter_linear, repeat_disable;

void vertex() {
	surface_normal = COLOR.rgb * 2.0 - 1.0;
	COLOR = vec4(1.0);
}

vec4 reflected_patch(vec3 normal, vec3 reflected_view, float fresnel, vec2 direction, vec4 color, float sharpness) {
	vec3 incoming = normalize(vec3(direction, 0.35));
	float lobe = exp(sharpness * (clamp(dot(reflected_view, incoming), -1.0, 1.0) - 1.0));
	// A bounded image of a colored object, rather than an emissive falloff.
	float coverage = smoothstep(0.35, 0.65, lobe);
	float visible = smoothstep(0.0, 0.25, dot(normal, incoming));
	float opacity = min(reflection_opacity_limit, color.a * coverage * visible * fresnel * reflection_strength * reflection_exposure);
	// Scale RGB equally to retain hue/saturation; white gloss is separate.
	return vec4(color.rgb * reflection_color_brightness, opacity);
}

vec4 over_patch(vec4 under, vec4 patch) {
	return vec4(patch.rgb * patch.a + under.rgb * (1.0 - patch.a), patch.a + under.a * (1.0 - patch.a));
}

float intensity(vec3 color) {
	return max(color.r, max(color.g, color.b));
}

vec3 ambient_light(vec3 normal, vec3 reflected_view, float fresnel, vec3 direction, vec4 color) {
	vec3 incoming = normalize(direction);
	float broad_reflection = exp(6.0 * (clamp(dot(reflected_view, incoming), -1.0, 1.0) - 1.0));
	return color.rgb * color.a * 0.30 * broad_reflection * fresnel;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	// Sample the smooth precomputed surface per pixel, independent of triangle
	// size and aspect ratio. No runtime blur or extra geometry is needed.
	vec3 normal = normalize(texture(surface_normal_texture, UV).rgb * 2.0 - 1.0);
	vec3 view = vec3(0.0, 0.0, 1.0);
	vec3 reflected_view = reflect(-view, normal);
	float fresnel = 0.04 + 0.96 * pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 5.0);
	vec4 reflection = vec4(0.0);
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_7, color_7, sharpness_7));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_6, color_6, sharpness_6));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_5, color_5, sharpness_5));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_4, color_4, sharpness_4));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_3, color_3, sharpness_3));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_2, color_2, sharpness_2));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_1, color_1, sharpness_1));
	reflection = over_patch(reflection, reflected_patch(normal, reflected_view, fresnel, direction_0, color_0, sharpness_0));
	float reflection_scale = min(1.0, reflection_total_opacity_limit / max(reflection.a, 0.001));
	reflection *= reflection_scale;
	vec3 illumination = environment_color.rgb * environment_strength * fresnel;
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_0, ambient_color_0);
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_1, ambient_color_1);
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_2, ambient_color_2);
	vec3 light = normalize(vec3(light_direction * 0.8, 0.9));
	vec3 half_vector = normalize(light + view);
	float highlight = smoothstep(cos(highlight_radius + highlight_edge), cos(highlight_radius - highlight_edge), dot(normal, half_vector)) * highlight_strength;
	float c = cos(secondary_highlight_angle);
	float s = sin(secondary_highlight_angle);
	vec2 opposite_direction = vec2(c * light_direction.x - s * light_direction.y, s * light_direction.x + c * light_direction.y);
	vec3 secondary_light = normalize(vec3(opposite_direction * 0.8, 0.9));
	vec3 secondary_half = normalize(secondary_light + view);
	float secondary = smoothstep(cos(secondary_highlight_radius + highlight_edge), cos(secondary_highlight_radius - highlight_edge), dot(normal, secondary_half)) * secondary_highlight_strength;
	highlight = 1.0 - (1.0 - highlight) * (1.0 - secondary);
	float environment_alpha = min(intensity(illumination), 0.12);
	vec4 surface = over_patch(reflection, vec4(illumination / max(environment_alpha, 0.001), environment_alpha));
	surface = over_patch(surface, vec4(vec3(1.0), highlight));
	COLOR = vec4(surface.rgb / max(surface.a, 0.001), mask * min(surface.a, 0.98));
}
