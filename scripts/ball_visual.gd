@tool
class_name BallVisual
extends Node2D

@export var tint_color: Color = Color.WHITE:
	set(value):
		tint_color = value
		_apply_tint()
@export_range(0.0, 0.9, 0.01) var shadow_darkening: float = 0.62:
	set(value):
		shadow_darkening = value
		_apply_tint()
@export_range(0.0, 16.0, 0.25) var outline_screen_width: float = 8.0
@export_range(0.0, 0.9, 0.01) var outline_darkening: float = 0.28:
	set(value):
		outline_darkening = value
		_apply_tint()

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
		var outline_color := tint_color.darkened(outline_darkening)
		outline_color.a = 0.95
		(shell_outline.material as ShaderMaterial).set_shader_parameter("outline_color", outline_color)
	if shell_shadow != null:
		shell_shadow.modulate = tint_color.darkened(shadow_darkening)


func _update_outline_width() -> void:
	var shell_outline := get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline == null or not shell_outline.material is ShaderMaterial:
		return
	var global_scale := get_global_transform().get_scale()
	var effective_scale := maxf(absf(global_scale.x), absf(global_scale.y))
	if is_equal_approx(effective_scale, _last_global_scale):
		return
	_last_global_scale = effective_scale
	var local_width := outline_screen_width / maxf(effective_scale, 0.001)
	(shell_outline.material as ShaderMaterial).set_shader_parameter("outline_texel_width", local_width)
