shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/pond_surface_reflection.gdshaderinc"

void fragment() {
	COLOR = pond_surface_reflection(UV, texture(TEXTURE, UV).a);
}
