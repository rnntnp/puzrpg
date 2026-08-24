@tool
class_name BallVisual
extends Node2D

enum OutlineShape {
	ELLIPSE,
	HEART,
}

@export var tint_color: Color = Color.WHITE:
	set(value):
		tint_color = value
		_apply_tint()
@export_range(0.0, 0.9, 0.01) var shadow_darkening: float = 0.62:
	set(value):
		shadow_darkening = value
		_apply_tint()
@export_range(0.0, 16.0, 0.25) var outline_screen_width: float = 4.0
@export_range(0.0, 16.0, 0.25) var inner_white_screen_width: float = 2.0
@export_range(0.0, 0.9, 0.01) var outline_darkening: float = 0.1:
	set(value):
		outline_darkening = value
		_apply_tint()
@export var outline_shape: OutlineShape = OutlineShape.ELLIPSE

var _last_global_scale := -1.0


func _ready() -> void:
	_apply_tint()
	_update_outline_width()


func _process(_delta: float) -> void:
	_update_outline_width()


func _apply_tint() -> void:
	var shell_base := get_node_or_null("ShellBase") as Sprite2D
	var shell_outline := get_node_or_null("ShellOutline") as Sprite2D
	var shell_shadow := get_node_or_null("ShellShadow") as Sprite2D
	if shell_base != null:
		shell_base.modulate = tint_color
	if shell_outline != null and shell_outline.material is ShaderMaterial:
		var color_darkening := outline_darkening
		var outline_color := tint_color.darkened(color_darkening)
		outline_color.a = 0.95
		(shell_outline.material as ShaderMaterial).set_shader_parameter("outline_color", outline_color)
	if shell_shadow != null:
		shell_shadow.modulate = tint_color.darkened(shadow_darkening)


func _update_outline_width() -> void:
	var shell_outline := get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline == null or not shell_outline.material is ShaderMaterial:
		return
	var global_scale := shell_outline.get_global_transform_with_canvas().get_scale()
	var effective_scale := maxf(absf(global_scale.x), absf(global_scale.y))
	if is_equal_approx(effective_scale, _last_global_scale):
		return
	_last_global_scale = effective_scale
	var safe_scale := maxf(effective_scale, 0.001)
	var total_screen_width := outline_screen_width + inner_white_screen_width
	var expansion_texels := total_screen_width / safe_scale
	var texture_size: Vector2 = shell_outline.texture.get_size() if shell_outline.texture != null else Vector2(418.0, 418.0)
	var expansion_ratio := 1.0 + expansion_texels * 2.0 / maxf(texture_size.x, 1.0)
	var expanded_screen_scale := safe_scale * expansion_ratio
	var color_local_width := outline_screen_width / expanded_screen_scale
	var total_local_width := total_screen_width / expanded_screen_scale
	var outline_material := shell_outline.material as ShaderMaterial
	outline_material.set_shader_parameter("outline_expand_texels", expansion_texels)
	outline_material.set_shader_parameter("outline_color_texel_width", color_local_width)
	outline_material.set_shader_parameter("outline_total_texel_width", total_local_width)
