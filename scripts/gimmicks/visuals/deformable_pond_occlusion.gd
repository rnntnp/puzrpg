extends "res://scripts/gimmicks/visuals/pond_ball_occlusion.gd"
## Reuse stage 62 ownership/cut-border shaders without its visual-warp controls.
var occlusion_enabled := true
var occlusion_button: Button
@export var show_debug_controls := true
const OwnershipShader = preload("res://shaders/deformable_pond_ownership.gdshader")
const DistanceField = preload("res://scripts/gimmicks/visuals/deformable_pond_sdf.gd")
var distance_field: RefCounted

func _ownership_scale() -> float:
	# Subpixel silhouette precision; encoded owner IDs must stay unfiltered.
	return 2.0

var mask_pool: Array[MeshInstance2D] = []
var mask_allocations := 0
var mask_reuses := 0
func configure(soft_layer: Node2D) -> void:
	layer = soft_layer
	process_priority = 100
	viewport = SubViewport.new()
	viewport.name = "BallOwnership"
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	distance_field=DistanceField.new()
	distance_field.configure(self)
	if show_debug_controls: _create_border_toggle()

func _create_border_toggle() -> void:
	var hud := CanvasLayer.new()
	hud.name = "CutBorderHUD"
	hud.layer = 100
	add_child(hud)
	occlusion_button = Button.new()
	occlusion_button.name = "OcclusionToggle"
	occlusion_button.text = "공 가림 켜짐"
	occlusion_button.toggle_mode = true
	occlusion_button.button_pressed = occlusion_enabled
	occlusion_button.position = Vector2(10, 84)
	occlusion_button.custom_minimum_size = Vector2(180, 44)
	occlusion_button.add_theme_font_size_override("font_size", 20)
	occlusion_button.focus_mode = Control.FOCUS_NONE
	occlusion_button.toggled.connect(_on_occlusion_toggled)
	hud.add_child(occlusion_button)

func _on_occlusion_toggled(value: bool) -> void:
	occlusion_enabled = value
	cut_border_enabled = value
	if is_instance_valid(occlusion_button): occlusion_button.text = "공 가림 켜짐" if value else "공 가림 꺼짐"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	distance_field.set_enabled(value and layer.tuning.cut_border_width_px>0.0)
	if value: return
	for record: Dictionary in materials.values():
		if not is_instance_valid(record.material): continue
		record.material.set_shader_parameter("ball_occlusion_enabled", false)
		if record.material.shader in shader_cache.values(): record.material.shader = record.original
	materials.clear()
	for mask in masks.values(): _release_mask(mask)
	masks.clear()

func _process(delta: float) -> void:
	if not occlusion_enabled: return
	# Retire merged sources before acquiring masks for the results in this frame.
	for id in masks.keys():
		var state: Dictionary = layer.states.get(id, {})
		if state.is_empty() or not is_instance_valid(state.ball) or state.ball.merge_locked or state.ball.is_queued_for_deletion():
			_release_mask(masks[id])
			masks.erase(id)
	super._process(delta)
	distance_field.resize(viewport.size)

func _create_mask(_source_shader: Shader) -> MeshInstance2D:
	if not mask_pool.is_empty():
		var reused: MeshInstance2D = mask_pool.pop_back()
		reused.show()
		mask_reuses += 1
		return reused
	var mask := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = OwnershipShader
	mask.material = material
	viewport.add_child(mask)
	mask_allocations += 1
	return mask

func _configure_cut_metrics(material: ShaderMaterial, shell_node: MeshInstance2D) -> void:
	material.set_shader_parameter("ball_cut_sdf_enabled",true)
	material.set_shader_parameter("ball_cut_sdf",distance_field.texture())
	material.set_shader_parameter("ball_cut_metric_correct",true)
	material.set_shader_parameter("ball_cut_color_texels",material.get_shader_parameter("outline_color_texel_width"))
	material.set_shader_parameter("ball_cut_total_texels",material.get_shader_parameter("outline_total_texel_width"))
	# The authored outline is a screen-width control. Do not shrink a seam
	# with the soft body's local compression or its UV derivative.
	var visual: Node=shell_node.get_parent()
	var colored: float=visual.get("outline_screen_width")
	var white: float=visual.get("inner_white_screen_width")
	var ratio: float=layer.tuning.cut_border_width_px/maxf(colored+white,0.001)
	colored*=ratio
	white*=ratio
	material.set_shader_parameter("ball_cut_border_enabled",cut_border_enabled and layer.tuning.cut_border_width_px>0.0)
	material.set_shader_parameter("ball_cut_fixed_width",true)
	material.set_shader_parameter("ball_cut_screen_widths",Vector2(colored,colored+white))

func _release_mask(mask: MeshInstance2D) -> void:
	mask.hide()
	if mask_pool.size()<64: mask_pool.append(mask)
	else: mask.queue_free()

