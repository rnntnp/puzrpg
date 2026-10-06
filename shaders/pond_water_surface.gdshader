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
uniform float reflection_exposure = 18.0;
uniform float rim_shadow_strength = 0.16;
uniform float rim_reflection_strength = 0.12;
uniform float softbox_aspect = 2.2;
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

vec3 reflected_color(vec3 normal, vec3 reflected_view, float fresnel, vec2 direction, vec4 color, float sharpness) {
	vec3 incoming = normalize(vec3(direction, 0.35));
	float lobe = exp(sharpness * (clamp(dot(reflected_view, incoming), -1.0, 1.0) - 1.0));
	float visible = max(dot(normal, incoming), 0.0);
	// Exposure compensates for using a transparent overlay over painted sprites.
	return color.rgb * color.a * lobe * visible * fresnel * reflection_strength * reflection_exposure;
}

float intensity(vec3 color) {
	return max(color.r, max(color.g, color.b));
}

vec3 ambient_light(vec3 normal, vec3 reflected_view, float fresnel, vec3 direction, vec4 color) {
	vec3 incoming = normalize(direction);
	float broad_reflection = exp(6.0 * (clamp(dot(reflected_view, incoming), -1.0, 1.0) - 1.0));
	float diffuse_fill = max(dot(normal, incoming), 0.0);
	return color.rgb * color.a * (0.70 * broad_reflection * (0.35 + 0.65 * fresnel) + 0.15 * diffuse_fill);
}

// Analytic area-light image in reflection space: no screen copy or refraction.
float softbox(vec3 reflected_view, vec2 direction, float radius, float strength) {
	vec3 light = normalize(vec3(direction, 0.22));
	vec3 tangent = normalize(vec3(-direction.y, direction.x, 0.0));
	vec3 bitangent = normalize(cross(light, tangent));
	vec2 q = vec2(dot(reflected_view, tangent), dot(reflected_view, bitangent));
	q /= vec2(sin(radius) * softbox_aspect, sin(radius));
	float shape = 1.0 - smoothstep(0.68, 1.0, length(q));
	float front = smoothstep(0.0, 0.25, dot(reflected_view, light));
	return shape * front * strength;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	// Sample the smooth precomputed surface per pixel, independent of triangle
	// size and aspect ratio. No runtime blur or extra geometry is needed.
	vec3 normal = normalize(texture(surface_normal_texture, UV).rgb * 2.0 - 1.0);
	vec3 view = vec3(0.0, 0.0, 1.0);
	vec3 reflected_view = reflect(-view, normal);
	float fresnel = 0.04 + 0.96 * pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 5.0);
	vec3 reflection = reflected_color(normal, reflected_view, fresnel, direction_0, color_0, sharpness_0);
	reflection += reflected_color(normal, reflected_view, fresnel, direction_1, color_1, sharpness_1);
	reflection += reflected_color(normal, reflected_view, fresnel, direction_2, color_2, sharpness_2);
	vec3 illumination = reflection + environment_color.rgb * environment_strength * fresnel;
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_0, ambient_color_0);
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_1, ambient_color_1);
	illumination += ambient_light(normal, reflected_view, fresnel, ambient_direction_2, ambient_color_2);
	float highlight = softbox(reflected_view, light_direction, highlight_radius, highlight_strength);
	float c = cos(secondary_highlight_angle);
	float s = sin(secondary_highlight_angle);
	vec2 opposite_direction = vec2(c * light_direction.x - s * light_direction.y, s * light_direction.x + c * light_direction.y);
	float secondary = softbox(reflected_view, opposite_direction, secondary_highlight_radius, secondary_highlight_strength);
	highlight = 1.0 - (1.0 - highlight) * (1.0 - secondary);
	illumination = illumination * (1.0 - highlight) + vec3(highlight);
	float edge = pow(1.0 - clamp(normal.z, 0.0, 1.0), 4.0);
	// Opposing light/dark edges suggest thickness without covering the center.
	float facing = dot(normal.xy, light_direction);
	float shadow = edge * rim_shadow_strength * smoothstep(-0.15, 0.65, -facing);
	illumination += vec3(edge * rim_reflection_strength * smoothstep(-0.25, 0.55, facing));
	float energy = intensity(illumination);
	float alpha = min(energy + shadow * (1.0 - energy), 0.98);
	COLOR = vec4(illumination / max(alpha, 0.001), mask * alpha);
}
