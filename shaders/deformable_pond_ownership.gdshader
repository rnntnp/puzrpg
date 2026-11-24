shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://shaders/soft_pond_deformation.gdshaderinc"
uniform vec3 mask_owner;
uniform float outline_expand_texels = 6.0;

void vertex() {
	VERTEX *= vec2(1.0) + TEXTURE_PIXEL_SIZE * outline_expand_texels * 2.0;
	VERTEX = soft_surface_vertex(VERTEX);
}

void fragment() {
	// Include the visible AA fringe without turning nearly transparent texture
	// residue into isolated hard ownership pixels and tiny cut contours.
	if (texture(TEXTURE, UV).a <= 0.1) { discard; }
	COLOR = vec4(mask_owner, 1.0);
}
