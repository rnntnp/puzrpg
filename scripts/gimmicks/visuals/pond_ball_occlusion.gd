extends Node2D
## Stage-owned silhouette ownership buffer. Background never enters this buffer.
var layer: Node2D
var viewport: SubViewport
var masks: Dictionary = {}
var materials: Dictionary = {}
var shader_cache: Dictionary = {}
var cut_border_enabled := true
const CUT_DEPTH_RATIO := 3.0
var warp_limit_label: Label
var response_time_label: Label
var face_gain_label: Label
var center_gain_label: Label
var base_press_time := 0.08
var base_release_time := 0.18

func configure(warp_layer: Node2D) -> void:
	layer = warp_layer
	base_press_time = layer.tuning.press_filter_time
	base_release_time = layer.tuning.release_filter_time
	process_priority = 100
	viewport = SubViewport.new()
	viewport.name = "BallOwnership"
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	_create_border_toggle()

func _create_border_toggle() -> void:
	if has_node("CutBorderHUD"): return
	var hud := CanvasLayer.new()
	hud.name = "CutBorderHUD"
	hud.layer = 100
	add_child(hud)
	var checkbox := CheckBox.new()
	checkbox.name = "CutBorderToggle"
	checkbox.text = "가림 외곽선"
	checkbox.position = Vector2(10, 52)
	checkbox.custom_minimum_size = Vector2(170, 44)
	checkbox.add_theme_font_size_override("font_size", 20)
	checkbox.button_pressed = cut_border_enabled
	checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_on_border_toggled)
	hud.add_child(checkbox)
	var row := HBoxContainer.new()
	row.name = "WarpLimitControl"
	row.position = Vector2(10, 96)
	row.add_theme_constant_override("separation", 8)
	hud.add_child(row)
	warp_limit_label = Label.new()
	warp_limit_label.custom_minimum_size.x = 135
	warp_limit_label.add_theme_font_size_override("font_size", 18)
	warp_limit_label.text = "변형량 %d%%" % roundi(layer.tuning.maximum_warp * 100.0)
	warp_limit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(warp_limit_label)
	var slider := HSlider.new()
	slider.name = "WarpLimitSlider"
	slider.min_value = 0.0
	slider.max_value = 0.4
	slider.step = 0.01
	slider.value = layer.tuning.maximum_warp
	slider.custom_minimum_size = Vector2(150, 32)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_warp_limit_changed)
	row.add_child(slider)
	var time_row := HBoxContainer.new()
	time_row.name = "WarpResponseControl"
	time_row.position = Vector2(330, 96)
	time_row.add_theme_constant_override("separation", 8)
	hud.add_child(time_row)
	response_time_label = Label.new()
	response_time_label.custom_minimum_size.x = 150
	response_time_label.add_theme_font_size_override("font_size", 18)
	response_time_label.text = "보간 시간 ×1.00"
	response_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(response_time_label)
	var time_slider := HSlider.new()
	time_slider.name = "WarpResponseSlider"
	time_slider.min_value = 0.1
	time_slider.max_value = 2.0
	time_slider.step = 0.05
	time_slider.value = 1.0
	time_slider.custom_minimum_size = Vector2(150, 32)
	time_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	time_slider.focus_mode = Control.FOCUS_NONE
	time_slider.tooltip_text = "낮을수록 빠르게 눌리고 풀립니다. 접촉·해제 보간 시간을 함께 조절합니다."
	time_slider.value_changed.connect(_on_response_time_changed)
	time_row.add_child(time_slider)
	var fit_checkbox := CheckBox.new()
	fit_checkbox.name = "SpriteContactFitToggle"
	fit_checkbox.text = "모양 접촉 보정"
	fit_checkbox.position = Vector2(210, 52)
	fit_checkbox.custom_minimum_size = Vector2(210, 44)
	fit_checkbox.add_theme_font_size_override("font_size", 20)
	fit_checkbox.button_pressed = layer.tuning.sprite_contact_fit_enabled
	fit_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	fit_checkbox.focus_mode = Control.FOCUS_NONE
	fit_checkbox.toggled.connect(_on_sprite_contact_fit_toggled)
	hud.add_child(fit_checkbox)
	var face_row := HBoxContainer.new()
	face_row.name = "FaceWarpControl"
	face_row.position = Vector2(10, 140)
	face_row.add_theme_constant_override("separation", 8)
	hud.add_child(face_row)
	face_gain_label = Label.new()
	face_gain_label.custom_minimum_size.x = 135
	face_gain_label.add_theme_font_size_override("font_size", 18)
	face_gain_label.text = "얼굴 변형 %d%%" % roundi(layer.tuning.face_strain_weight * 100.0)
	face_gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_row.add_child(face_gain_label)
	var face_slider := HSlider.new()
	face_slider.name = "FaceWarpSlider"
	face_slider.min_value = 0.0
	face_slider.max_value = 1.0
	face_slider.step = 0.05
	face_slider.value = layer.tuning.face_strain_weight
	face_slider.custom_minimum_size = Vector2(150, 32)
	face_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	face_slider.focus_mode = Control.FOCUS_NONE
	face_slider.tooltip_text = "0%는 표정의 모양을 유지하고 위치만 따라갑니다. 100%는 머리와 같은 정도로 변형됩니다."
	face_slider.value_changed.connect(_on_face_gain_changed)
	face_row.add_child(face_slider)
	var center_row := HBoxContainer.new()
	center_row.name = "CenterWarpControl"
	center_row.position = Vector2(330, 140)
	center_row.add_theme_constant_override("separation", 8)
	hud.add_child(center_row)
	center_gain_label = Label.new()
	center_gain_label.custom_minimum_size.x = 150
	center_gain_label.add_theme_font_size_override("font_size", 18)
	center_gain_label.text = "중앙 와핑 ×%.1f" % layer.tuning.interior_warp_gain
	center_gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.add_child(center_gain_label)
	var center_slider := HSlider.new()
	center_slider.name = "CenterWarpSlider"
	center_slider.min_value = 1.0
	center_slider.max_value = 10.0
	center_slider.step = 0.1
	center_slider.value = layer.tuning.interior_warp_gain
	center_slider.custom_minimum_size = Vector2(150, 32)
	center_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	center_slider.focus_mode = Control.FOCUS_NONE
	center_slider.tooltip_text = "머리 중심부의 와핑을 강조합니다. 표정에는 얼굴 변형 비율이 추가로 적용됩니다."
	center_slider.value_changed.connect(_on_center_gain_changed)
	center_row.add_child(center_slider)

func _on_center_gain_changed(value: float) -> void:
	if not is_instance_valid(layer): return
	layer.tuning.interior_warp_gain = value
	for state: Dictionary in layer.states.values():
		if not is_instance_valid(state.ball): continue
		state.interior_warp_gain = value if layer.exaggerate_face_warp else 1.0
		state.published_points = PackedVector2Array()
	if is_instance_valid(center_gain_label):
		center_gain_label.text = "중앙 와핑 ×%.1f" % value

func _on_face_gain_changed(value: float) -> void:
	if not is_instance_valid(layer): return
	layer.tuning.face_strain_weight = value
	for state: Dictionary in layer.states.values():
		if not is_instance_valid(state.ball): continue
		state.face_strain_weight = value if layer.exaggerate_face_warp else 1.0
		# Refresh stationary meshes too; their control points need not move.
		state.published_points = PackedVector2Array()
	if is_instance_valid(face_gain_label):
		face_gain_label.text = "얼굴 변형 %d%%" % roundi(value * 100.0)

func _on_sprite_contact_fit_toggled(enabled: bool) -> void:
	if is_instance_valid(layer): layer.tuning.sprite_contact_fit_enabled = enabled

func _on_response_time_changed(value: float) -> void:
	if not is_instance_valid(layer): return
	layer.tuning.press_filter_time = base_press_time * value
	layer.tuning.release_filter_time = base_release_time * value
	if is_instance_valid(response_time_label):
		response_time_label.text = "보간 시간 ×%.2f" % value

func _on_warp_limit_changed(value: float) -> void:
	if not is_instance_valid(layer): return
	layer.tuning.maximum_warp = value
	if is_instance_valid(warp_limit_label):
		warp_limit_label.text = "변형량 %d%%" % roundi(value * 100.0)

func _on_border_toggled(enabled: bool) -> void:
	cut_border_enabled = enabled
	for record: Dictionary in materials.values():
		if is_instance_valid(record.material) and record.original.code.contains("uniform vec4 outline_color"):
			record.material.set_shader_parameter("ball_cut_border_enabled", enabled)

func _fragment_variant(code: String, fragment: String) -> String:
	var start := code.find("void fragment()")
	if start < 0: return code + "\nvoid fragment() {\n" + fragment + "\n}\n"
	var opening := code.find("{", start)
	var depth := 1
	var end := opening + 1
	while depth > 0 and end < code.length():
		if code[end] == "{": depth += 1
		elif code[end] == "}": depth -= 1
		end += 1
	return code.substr(0, opening + 1) + fragment + code.substr(end - 1)

func _install(material: ShaderMaterial) -> void:
	if materials.has(material.get_instance_id()): return
	var original := material.shader
	var code := original.code
	if not shader_cache.has(code):
		var guarded := code.replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform sampler2D ball_ownership : filter_nearest, repeat_disable;\nuniform vec3 ball_owner;\nuniform bool ball_occlusion_enabled = false;\n")
		var start := guarded.find("void fragment()")
		if start >= 0:
			var opening := guarded.find("{", start)
			guarded = guarded.insert(opening + 1, "\nif (ball_occlusion_enabled) { vec4 owner = texture(ball_ownership, SCREEN_UV); if (owner.a > 0.5 && distance(owner.rgb, ball_owner) > 0.002) { discard; } }\n")
		else:
			guarded += "\nvoid fragment() { vec4 owner = texture(ball_ownership, SCREEN_UV); if (ball_occlusion_enabled && owner.a > 0.5 && distance(owner.rgb, ball_owner) > 0.002) { discard; } COLOR *= texture(TEXTURE, UV); }\n"
		if code.contains("uniform vec4 outline_color"):
			guarded = guarded.replace("uniform bool ball_occlusion_enabled = false;", "uniform bool ball_occlusion_enabled = false;\n#include \"res://shaders/pond_ball_cut_border.gdshaderinc\"\n")
			var fragment_start := guarded.find("void fragment()")
			var fragment_open := guarded.find("{", fragment_start)
			var depth := 1
			var cursor := fragment_open + 1
			while depth > 0 and cursor < guarded.length():
				if guarded[cursor] == "{": depth += 1
				elif guarded[cursor] == "}": depth -= 1
				cursor += 1
			guarded = guarded.insert(cursor - 1, "\nif (ball_occlusion_enabled && ball_cut_border_enabled) { vec4 cut = ball_cut_border(SCREEN_UV, SCREEN_PIXEL_SIZE, color_complete_band, TEXTURE, UV, dFdx(UV), dFdy(UV)); COLOR.rgb = mix(COLOR.rgb, cut.rgb, cut.a / max(cut.a + COLOR.a * (1.0 - cut.a), 0.0001)); COLOR.a = cut.a + COLOR.a * (1.0 - cut.a); }\n")
		var shader := Shader.new()
		shader.code = guarded
		shader_cache[code] = shader
	material.shader = shader_cache[code]
	materials[material.get_instance_id()] = {"material":material, "original":original}

func _process(_delta: float) -> void:
	if not is_instance_valid(layer) or viewport == null: return
	viewport.size = Vector2i(layer.get_viewport().get_visible_rect().size)
	var present := {}
	var present_materials := {}
	var order := 0
	for state: Dictionary in layer.states.values():
		# Physics cleanup runs at 60 Hz; rendering may still see a freed source
		# between ticks. Check the Variant before assigning it to a typed object.
		if not is_instance_valid(state.ball): continue
		var ball: MergeBall = state.ball
		if not is_instance_valid(ball) or ball.is_queued_for_deletion() or ball.merge_locked: continue
		var id := ball.get_instance_id()
		# Encode draw priority, so only the rear ball creates a cut border.
		var priority := order + 1
		var owner := Vector3(float(priority % 255) / 255.0, float((priority / 255) % 255) / 255.0, float((priority / 65025) % 255) / 255.0)
		var shell: Dictionary = {}
		for record: Dictionary in state.visuals.records:
			if not is_instance_valid(record.mesh_node) or not is_instance_valid(record.source): continue
			if record.source.name == &"ShellOutline": shell = record
			var material: ShaderMaterial = record.material
			_install(material)
			present_materials[material.get_instance_id()] = true
			material.set_shader_parameter("ball_ownership", viewport.get_texture())
			material.set_shader_parameter("ball_owner", owner)
			material.set_shader_parameter("ball_occlusion_enabled", true)
		if shell.is_empty(): continue
		var shell_material: ShaderMaterial = shell.material
		var shell_node: MeshInstance2D = shell.mesh_node
		var pixel_scale := shell_node.get_global_transform_with_canvas().x.length()
		var color_width: float = shell_material.get_shader_parameter("outline_color_texel_width")
		var total_width: float = shell_material.get_shader_parameter("outline_total_texel_width")
		shell_material.set_shader_parameter("ball_cut_border_enabled", cut_border_enabled)
		shell_material.set_shader_parameter("ball_cut_depth_ratio", CUT_DEPTH_RATIO)
		shell_material.set_shader_parameter("ball_cut_color", shell_material.get_shader_parameter("outline_color"))
		shell_material.set_shader_parameter("ball_cut_color_width", maxf(0.75, color_width * pixel_scale))
		shell_material.set_shader_parameter("ball_cut_white_width", maxf(0.75, (total_width - color_width) * pixel_scale))
		present[id] = true
		if not masks.has(id):
			var mask := MeshInstance2D.new()
			var source_shader: Shader = materials[shell.material.get_instance_id()].original
			var mask_shader := Shader.new()
			var code := source_shader.code.replace("render_mode unshaded;", "render_mode unshaded, blend_disabled;")
			code = code.replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform vec3 mask_owner;\n")
			mask_shader.code = _fragment_variant(code, "\nif (texture(TEXTURE, UV).a < 0.5) { discard; } COLOR = vec4(mask_owner, 1.0);\n")
			var mask_material := ShaderMaterial.new()
			mask_material.shader = mask_shader
			mask.material = mask_material
			viewport.add_child(mask)
			masks[id] = mask
		var mask: MeshInstance2D = masks[id]
		var source: MeshInstance2D = shell.mesh_node
		mask.mesh = source.mesh
		mask.texture = source.texture
		mask.transform = source.get_global_transform_with_canvas()
		mask.z_index = order
		order += 1
		var mask_material := mask.material as ShaderMaterial
		mask_material.set_shader_parameter("mask_owner", owner)
		for parameter in ["outline_expand_texels", "soft_basis", "soft_inverse", "soft_origin", "soft_deformation", "soft_offset", "soft_point_count", "soft_rest_points", "soft_point_offsets"]:
			var value: Variant = shell.material.get_shader_parameter(parameter)
			if value != null: mask_material.set_shader_parameter(parameter, value)
	for id in masks.keys():
		if not present.has(id):
			masks[id].queue_free()
			masks.erase(id)
	for id in materials.keys():
		var record: Dictionary = materials[id]
		if not present_materials.has(id):
			if is_instance_valid(record.material) and record.material.shader in shader_cache.values():
				record.material.shader = record.original
			materials.erase(id)

func _exit_tree() -> void:
	for record: Dictionary in materials.values():
		if is_instance_valid(record.material):
			record.material.set_shader_parameter("ball_occlusion_enabled", false)
			if record.material.shader in shader_cache.values(): record.material.shader = record.original
	materials.clear()
