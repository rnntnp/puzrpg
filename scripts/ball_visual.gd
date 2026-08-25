@tool
class_name BallVisual
extends Node2D

const FROZEN_SHEEN_SHADER := preload("res://shaders/frozen_ball_sheen.gdshader")
const ICE_TARGET_WAVE_SHADER := preload("res://shaders/ice_target_radial_wave.gdshader")

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
@export_group("Frozen Sheen")
@export_range(0.4, 4.0, 0.05) var frozen_sheen_cycle_seconds: float = 1.5
@export_range(0.04, 0.5, 0.01) var frozen_sheen_band_width: float = 0.18
@export_range(0.005, 0.2, 0.005) var frozen_sheen_softness: float = 0.06
@export_range(-2.0, 2.0, 0.05) var frozen_sheen_diagonal_slope: float = 0.65
@export var frozen_matte_color: Color = Color(0.66, 0.88, 0.96, 0.8)
@export var frozen_sheen_color: Color = Color(0.95, 0.99, 1.0, 0.8)
@export_range(0.0, 16.0, 0.25) var frozen_outer_screen_width: float = 7.0
@export var frozen_outer_color: Color = Color.WHITE
@export_group("Ice Target Telegraph")
@export_range(8.0, 48.0, 0.5) var ice_target_wave_distance: float = 28.0
@export_range(1.0, 10.0, 0.25) var ice_target_wave_screen_width: float = 4.0
@export_range(0.2, 3.0, 0.05) var ice_target_wave_cycle_seconds: float = 0.85
@export var ice_target_wave_color: Color = Color(1.0, 1.0, 1.0, 0.9)

var _last_global_scale := -1.0
var _frozen_sheen: Sprite2D
var _gloss_was_visible := true
var _is_frozen_visual := false
var _ice_target_outline: Sprite2D
var _ice_targeted_visual := false
var _target_wave_color := ice_target_wave_color


func _ready() -> void:
	_apply_tint()
	_update_outline_width()
	_setup_frozen_sheen()
	_setup_ice_target_outline()


func _process(_delta: float) -> void:
	_update_outline_width()


func set_frozen_visual(enabled: bool) -> void:
	_setup_frozen_sheen()
	var shell_gloss := get_node_or_null("ShellGloss") as Sprite2D
	if enabled:
		var was_already_frozen := _frozen_sheen != null and _frozen_sheen.visible
		if shell_gloss != null and not was_already_frozen:
			_gloss_was_visible = shell_gloss.visible
			shell_gloss.visible = false
		if _frozen_sheen != null:
			_frozen_sheen.visible = true
	else:
		if shell_gloss != null:
			shell_gloss.visible = _gloss_was_visible
		if _frozen_sheen != null:
			_frozen_sheen.visible = false
	_is_frozen_visual = enabled
	_last_global_scale = -1.0
	_update_outline_width()


func set_ice_targeted_visual(enabled: bool) -> void:
	set_targeted_visual(enabled, ice_target_wave_color)


func set_targeted_visual(enabled: bool, color: Color) -> void:
	_setup_ice_target_outline()
	_ice_targeted_visual = enabled
	_target_wave_color = color
	if _ice_target_outline != null:
		_ice_target_outline.visible = enabled
	_last_global_scale = -1.0
	_update_outline_width()


func _setup_frozen_sheen() -> void:
	if _frozen_sheen != null and is_instance_valid(_frozen_sheen):
		_update_frozen_sheen_parameters()
		return
	var shell_outline := get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline == null or shell_outline.texture == null:
		return
	_frozen_sheen = Sprite2D.new()
	_frozen_sheen.name = "FrozenSheen"
	_frozen_sheen.texture = shell_outline.texture
	_frozen_sheen.texture_filter = shell_outline.texture_filter
	_frozen_sheen.position = shell_outline.position
	_frozen_sheen.rotation = shell_outline.rotation
	_frozen_sheen.scale = shell_outline.scale
	_frozen_sheen.z_index = 2
	_frozen_sheen.visible = false
	var sheen_material := ShaderMaterial.new()
	sheen_material.shader = FROZEN_SHEEN_SHADER
	_frozen_sheen.material = sheen_material
	add_child(_frozen_sheen)
	_update_frozen_sheen_parameters()


func _update_frozen_sheen_parameters() -> void:
	if _frozen_sheen == null or not (_frozen_sheen.material is ShaderMaterial):
		return
	var sheen_material := _frozen_sheen.material as ShaderMaterial
	sheen_material.set_shader_parameter("cycle_seconds", frozen_sheen_cycle_seconds)
	sheen_material.set_shader_parameter("band_width", frozen_sheen_band_width)
	sheen_material.set_shader_parameter("band_softness", frozen_sheen_softness)
	sheen_material.set_shader_parameter("diagonal_slope", frozen_sheen_diagonal_slope)
	sheen_material.set_shader_parameter("matte_color", frozen_matte_color)
	sheen_material.set_shader_parameter("sheen_color", frozen_sheen_color)


func _setup_ice_target_outline() -> void:
	if _ice_target_outline != null and is_instance_valid(_ice_target_outline):
		return
	var shell_outline := get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline == null or shell_outline.texture == null:
		return
	_ice_target_outline = Sprite2D.new()
	_ice_target_outline.name = "IceTargetRadialWave"
	_ice_target_outline.texture = shell_outline.texture
	_ice_target_outline.texture_filter = shell_outline.texture_filter
	_ice_target_outline.position = shell_outline.position
	_ice_target_outline.rotation = shell_outline.rotation
	_ice_target_outline.scale = shell_outline.scale
	_ice_target_outline.z_index = 4
	_ice_target_outline.visible = false
	var target_material := ShaderMaterial.new()
	target_material.shader = ICE_TARGET_WAVE_SHADER
	_ice_target_outline.material = target_material
	add_child(_ice_target_outline)


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
	var base_total_screen_width := outline_screen_width + inner_white_screen_width
	var total_screen_width := base_total_screen_width + (frozen_outer_screen_width if _is_frozen_visual else 0.0)
	var expansion_texels := total_screen_width / safe_scale
	var texture_size: Vector2 = shell_outline.texture.get_size() if shell_outline.texture != null else Vector2(418.0, 418.0)
	var expansion_ratio := 1.0 + expansion_texels * 2.0 / maxf(texture_size.x, 1.0)
	var expanded_screen_scale := safe_scale * expansion_ratio
	var color_screen_width := outline_screen_width
	var base_total_with_offset := base_total_screen_width
	if _is_frozen_visual:
		color_screen_width += frozen_outer_screen_width
		base_total_with_offset += frozen_outer_screen_width
	var color_local_width := color_screen_width / expanded_screen_scale
	var base_total_local_width := base_total_with_offset / expanded_screen_scale
	var frozen_outer_local_width := frozen_outer_screen_width / expanded_screen_scale
	var outline_material := shell_outline.material as ShaderMaterial
	outline_material.set_shader_parameter("outline_expand_texels", expansion_texels)
	outline_material.set_shader_parameter("outline_color_texel_width", color_local_width)
	outline_material.set_shader_parameter("outline_total_texel_width", base_total_local_width)
	outline_material.set_shader_parameter("frozen_enabled", _is_frozen_visual)
	outline_material.set_shader_parameter("frozen_outer_color", frozen_outer_color)
	outline_material.set_shader_parameter("frozen_outer_texel_width", frozen_outer_local_width)
	_update_ice_target_outline_width(safe_scale, texture_size)


func _update_ice_target_outline_width(safe_scale: float, texture_size: Vector2) -> void:
	if _ice_target_outline == null or not (_ice_target_outline.material is ShaderMaterial):
		return
	var base_outer_width := outline_screen_width + inner_white_screen_width
	if _is_frozen_visual:
		base_outer_width += frozen_outer_screen_width
	var target_expansion_screen := base_outer_width + ice_target_wave_distance
	var expansion_texels := target_expansion_screen / safe_scale
	var expansion_ratio := 1.0 + expansion_texels * 2.0 / maxf(texture_size.x, 1.0)
	var expanded_screen_scale := safe_scale * expansion_ratio
	var original_half_screen_size := texture_size.x * safe_scale * 0.5
	var expanded_screen_size := texture_size.x * expanded_screen_scale
	var start_radius := (original_half_screen_size + base_outer_width) / maxf(expanded_screen_size, 1.0)
	var wave_uv_width := ice_target_wave_screen_width / maxf(texture_size.x * expanded_screen_scale, 1.0)
	var target_material := _ice_target_outline.material as ShaderMaterial
	target_material.set_shader_parameter("expansion_texels", expansion_texels)
	target_material.set_shader_parameter("start_radius", start_radius)
	target_material.set_shader_parameter("wave_width", wave_uv_width)
	target_material.set_shader_parameter("cycle_seconds", ice_target_wave_cycle_seconds)
	var wave_color := _target_wave_color
	wave_color.a = ice_target_wave_color.a
	target_material.set_shader_parameter("wave_color", wave_color)
