class_name StageIntroSequence
extends CanvasLayer

signal sequence_finished
signal tutorial_control_page_shown

const LOGO_FADE_DURATION := 0.45
const LOGO_HOLD_DURATION := 0.7
const TutorialMouseCursorClass = preload("res://scripts/tutorial_mouse_cursor.gd")
const TutorialControlArrowClass = preload("res://scripts/tutorial_control_arrow.gd")

var _pages: PackedStringArray = []
var _story_images: Array[Texture2D] = []
var _page_index := 0
var _logo_first := false
var _enemy_intent_tutorial := false
var _control_only_tutorial := false
var _turn_tutorial := false
var _evolution_tutorial := false
var _combo_tutorial := false
var _custom_spotlight_tutorial := false
var _custom_spotlight_center := Vector2.ZERO
var _custom_spotlight_radius := 72.0
var _custom_spotlight_box_half_size := Vector2.ZERO
var _control_center_x := 360.0
var _backdrop: ColorRect
var _label: Label
var _story_image: TextureRect
var _guide_panel: Panel
var _guide_label: Label
var _click_hint: Label
var _control_arrow: TutorialControlArrow
var _mouse_cursor: TutorialMouseCursor


func play_story(pages: PackedStringArray, story_images: Array[Texture2D] = []) -> void:
	_logo_first = not pages.is_empty() and pages[0] == "로고"
	_story_images = story_images
	_enemy_intent_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = false
	_play(pages)


func play_tutorial(pages: PackedStringArray, control_center_x := 360.0) -> void:
	_logo_first = false
	_enemy_intent_tutorial = true
	_control_only_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = false
	_control_center_x = control_center_x
	_play(pages)


func play_control_tutorial(control_center_x := 360.0) -> void:
	_logo_first = false
	_enemy_intent_tutorial = true
	_control_only_tutorial = true
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = false
	_control_center_x = control_center_x
	_play(PackedStringArray(["드롭 조작"]))


func play_turn_tutorial(message: String) -> void:
	_logo_first = false
	_enemy_intent_tutorial = false
	_turn_tutorial = true
	_evolution_tutorial = false
	_combo_tutorial = false
	_play(PackedStringArray([message]))


func play_evolution_tutorial(messages: PackedStringArray) -> void:
	_logo_first = false
	_enemy_intent_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = true
	_combo_tutorial = false
	_play(messages)


func play_combo_tutorial(message: String) -> void:
	_logo_first = false
	_enemy_intent_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = true
	_play(PackedStringArray([message]))


func play_custom_spotlight_tutorial(message: String, center: Vector2, radius := 72.0) -> void:
	_logo_first = false
	_enemy_intent_tutorial = false
	_control_only_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = false
	_custom_spotlight_tutorial = true
	_custom_spotlight_center = center
	_custom_spotlight_radius = radius
	_custom_spotlight_box_half_size = Vector2.ZERO
	_play(PackedStringArray([message]))


func play_custom_box_spotlight_tutorial(message: String, center: Vector2, half_size: Vector2) -> void:
	_logo_first = false
	_enemy_intent_tutorial = false
	_control_only_tutorial = false
	_turn_tutorial = false
	_evolution_tutorial = false
	_combo_tutorial = false
	_custom_spotlight_tutorial = true
	_custom_spotlight_center = center
	_custom_spotlight_box_half_size = half_size
	_play(PackedStringArray([message]))


func _play(pages: PackedStringArray) -> void:
	_pages = pages
	if _pages.is_empty():
		_finish()
		return
	_build_overlay()
	_show_current_page()


func _build_overlay() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.07, 0.96)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_label = Label.new()
	_label.position = Vector2(60.0, 500.0)
	_label.size = Vector2(600.0, 120.0)
	_label.add_theme_font_size_override("font_size", 72)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(_label)

	_story_image = TextureRect.new()
	_story_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_story_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_story_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_image.hide()
	_backdrop.add_child(_story_image)

	_guide_panel = Panel.new()
	_guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_panel.hide()
	var guide_style := StyleBoxFlat.new()
	guide_style.bg_color = Color(0.025, 0.075, 0.18, 0.82)
	guide_style.border_color = Color(0.55, 0.78, 1.0, 0.42)
	guide_style.set_border_width_all(2)
	guide_style.set_corner_radius_all(16)
	_guide_panel.add_theme_stylebox_override("panel", guide_style)
	_backdrop.add_child(_guide_panel)

	_guide_label = Label.new()
	_guide_label.position = Vector2(70.0, 255.0)
	_guide_label.size = Vector2(580.0, 120.0)
	_guide_label.add_theme_font_size_override("font_size", 31)
	_guide_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_guide_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_guide_label.add_theme_constant_override("outline_size", 7)
	_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_label.hide()
	_backdrop.add_child(_guide_label)

	_click_hint = Label.new()
	_click_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_click_hint.offset_top = -120.0
	_click_hint.offset_bottom = -80.0
	_click_hint.add_theme_font_size_override("font_size", 26)
	_click_hint.add_theme_color_override("font_color", Color.WHITE)
	_click_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.98))
	_click_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_click_hint.add_theme_constant_override("outline_size", 3)
	_click_hint.add_theme_constant_override("shadow_offset_x", 2)
	_click_hint.add_theme_constant_override("shadow_offset_y", 2)
	_click_hint.text = "클릭해서 계속"
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(_click_hint)

	_control_arrow = TutorialControlArrowClass.new()
	_control_arrow.position = Vector2(_control_center_x - 110.0, 610.0)
	_control_arrow.hide()
	_backdrop.add_child(_control_arrow)

	_mouse_cursor = TutorialMouseCursorClass.new()
	_mouse_cursor.position = Vector2(_control_center_x - 12.0, 665.0)
	_mouse_cursor.scale = Vector2(0.38, 0.38)
	_mouse_cursor.hide()
	_backdrop.add_child(_mouse_cursor)


func _show_current_page() -> void:
	_label.text = _pages[_page_index]
	_story_image.hide()
	if _logo_first and _page_index == 0:
		_set_spotlight(false)
		_guide_label.hide()
		_reset_page_title_layout()
		_click_hint.hide()
		_play_logo()
		return
	if _show_story_image_page():
		return
	if _enemy_intent_tutorial and _page_index == 0:
		if _control_only_tutorial:
			_show_drop_control_tutorial()
			return
		_show_enemy_intent_tutorial()
		return
	if _enemy_intent_tutorial and _page_index == 1:
		_show_drop_control_tutorial()
		return
	if _turn_tutorial and _page_index == 0:
		_show_turn_tutorial()
		return
	if _evolution_tutorial:
		_show_evolution_tutorial()
		return
	if _combo_tutorial:
		_show_combo_tutorial()
		return
	if _custom_spotlight_tutorial:
		_show_custom_spotlight_tutorial()
		return
	_set_spotlight(false)
	_guide_label.hide()
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_reset_page_title_layout()
	_label.show()
	_click_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_click_hint.position = Vector2(120.0, 1160.0)
	_click_hint.size = Vector2(480.0, 48.0)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.show()
	_label.modulate.a = 1.0


func _show_story_image_page() -> bool:
	var image_index := _page_index - 1 if _logo_first else _page_index
	if image_index < 0 or image_index >= _story_images.size():
		return false
	var texture := _story_images[image_index]
	if texture == null:
		return false
	_set_spotlight(false)
	_guide_label.hide()
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_label.hide()
	_story_image.texture = texture
	_story_image.show()
	_guide_panel.hide()
	_click_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_click_hint.position = Vector2(170.0, 1192.0)
	_click_hint.size = Vector2(380.0, 60.0)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_click_hint.add_theme_color_override("font_color", Color.WHITE)
	_click_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.98))
	_click_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_click_hint.add_theme_constant_override("outline_size", 3)
	_click_hint.show()
	return true


func _show_enemy_intent_tutorial() -> void:
	_set_spotlight(true)
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_reset_page_title_layout()
	_label.hide()
	_guide_label.text = "적의 머리 위에 다음 행동까지\n남은 턴 수를 알려줍니다."
	_guide_label.show()
	_label.modulate.a = 1.0
	_click_hint.show()


func _show_drop_control_tutorial() -> void:
	_set_spotlight(false)
	_backdrop.color = Color.TRANSPARENT
	_label.hide()
	_guide_panel.position = Vector2(_control_center_x - 250.0, 720.0)
	_guide_panel.size = Vector2(500.0, 115.0)
	_guide_panel.show()
	_guide_label.position = Vector2(_control_center_x - 240.0, 720.0)
	_guide_label.size = Vector2(480.0, 115.0)
	_guide_label.add_theme_font_size_override("font_size", 25)
	_guide_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82, 1.0))
	_guide_label.add_theme_constant_override("outline_size", 5)
	_guide_label.text = "좌우로 스와이프해 방울의 위치를 정하고\n클릭해 수조에 떨어뜨리세요."
	_guide_label.show()
	_control_arrow.show()
	_mouse_cursor.show()
	_click_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_click_hint.position = Vector2(430.0, 1060.0)
	_click_hint.size = Vector2(200.0, 42.0)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_click_hint.show()
	tutorial_control_page_shown.emit()


func _show_turn_tutorial() -> void:
	_set_spotlight(true)
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_label.hide()
	_guide_label.position = Vector2(70.0, 255.0)
	_guide_label.size = Vector2(580.0, 120.0)
	_guide_label.add_theme_font_size_override("font_size", 31)
	_guide_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_guide_label.add_theme_constant_override("outline_size", 7)
	_guide_label.text = _pages[_page_index]
	_guide_label.show()
	_click_hint.show()


func _show_evolution_tutorial() -> void:
	_set_evolution_spotlight()
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_label.hide()
	_guide_label.position = Vector2(120.0, 520.0)
	_guide_label.size = Vector2(540.0, 180.0)
	_guide_label.add_theme_font_size_override("font_size", 31)
	_guide_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_guide_label.add_theme_constant_override("outline_size", 7)
	_guide_label.text = _pages[_page_index]
	_guide_label.show()
	_click_hint.show()


func _show_combo_tutorial() -> void:
	_set_combo_stack_spotlight()
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_label.hide()
	_guide_label.position = Vector2(110.0, 530.0)
	_guide_label.size = Vector2(560.0, 100.0)
	_guide_label.add_theme_font_size_override("font_size", 31)
	_guide_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_guide_label.add_theme_constant_override("outline_size", 7)
	_guide_label.text = _pages[_page_index]
	_guide_label.show()
	_click_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_click_hint.position = Vector2(430.0, 1060.0)
	_click_hint.size = Vector2(210.0, 42.0)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_click_hint.show()


func _show_custom_spotlight_tutorial() -> void:
	if _custom_spotlight_box_half_size != Vector2.ZERO:
		_backdrop.material = _create_box_spotlight_material(_custom_spotlight_center, _custom_spotlight_box_half_size)
	else:
		_backdrop.material = _create_spotlight_material_at(_custom_spotlight_center, _custom_spotlight_radius)
	_guide_panel.hide()
	_control_arrow.hide()
	_mouse_cursor.hide()
	_label.hide()
	_guide_label.position = Vector2(70.0, 500.0)
	_guide_label.size = Vector2(580.0, 130.0)
	_guide_label.add_theme_font_size_override("font_size", 31)
	_guide_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_guide_label.add_theme_constant_override("outline_size", 7)
	_guide_label.text = _pages[_page_index]
	_guide_label.show()
	_click_hint.show()


func _set_combo_stack_spotlight() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

float rounded_box_sdf(vec2 point, vec2 center, vec2 half_size, float radius) {
	vec2 delta = abs(point - center) - half_size + vec2(radius);
	return length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - radius;
}

void fragment() {
	vec2 point = UV * vec2(720.0, 1280.0);
	float distance_from_stack = rounded_box_sdf(point, vec2(395.0, 970.0), vec2(112.0, 305.0), 32.0);
	float overlay_alpha = smoothstep(-2.0, 5.0, distance_from_stack) * 0.76;
	COLOR = vec4(0.02, 0.03, 0.07, overlay_alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_backdrop.material = material


func _reset_page_title_layout() -> void:
	_label.show()
	_label.position = Vector2(60.0, 500.0)
	_label.size = Vector2(600.0, 120.0)
	_label.add_theme_font_size_override("font_size", 72)


func _set_spotlight(enabled: bool) -> void:
	if enabled:
		_backdrop.material = _create_spotlight_material()
	else:
		_backdrop.material = null
		_backdrop.color = Color(0.02, 0.03, 0.07, 0.96)


func _set_evolution_spotlight() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

float rounded_box_sdf(vec2 point, vec2 center, vec2 half_size, float radius) {
	vec2 delta = abs(point - center) - half_size + vec2(radius);
	return length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - radius;
}

void fragment() {
	vec2 point = UV * vec2(720.0, 1280.0);
	float distance_from_rail = rounded_box_sdf(point, vec2(48.0, 890.0), vec2(48.0, 385.0), 20.0);
	float overlay_alpha = smoothstep(-2.0, 5.0, distance_from_rail) * 0.76;
	COLOR = vec4(0.02, 0.03, 0.07, overlay_alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_backdrop.material = material


func _create_spotlight_material() -> ShaderMaterial:
	return _create_spotlight_material_at(Vector2(534.0, 171.0), 72.0)


func _create_spotlight_material_at(center: Vector2, radius: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 point = UV * vec2(720.0, 1280.0);
	float distance_from_spotlight = distance(point, vec2(%0.2f, %0.2f));
	float overlay_alpha = smoothstep(%0.2f, %0.2f, distance_from_spotlight) * 0.76;
	COLOR = vec4(0.02, 0.03, 0.07, overlay_alpha);
}
""" % [center.x, center.y, radius - 8.0, radius]
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _create_box_spotlight_material(center: Vector2, half_size: Vector2) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

float rounded_box_sdf(vec2 point, vec2 center, vec2 half_size, float radius) {
	vec2 delta = abs(point - center) - half_size + vec2(radius);
	return length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - radius;
}

void fragment() {
	vec2 point = UV * vec2(720.0, 1280.0);
	float distance_from_spotlight = rounded_box_sdf(point, vec2(%0.2f, %0.2f), vec2(%0.2f, %0.2f), 24.0);
	float overlay_alpha = smoothstep(-2.0, 6.0, distance_from_spotlight) * 0.76;
	COLOR = vec4(0.02, 0.03, 0.07, overlay_alpha);
}
""" % [center.x, center.y, half_size.x, half_size.y]
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _play_logo() -> void:
	_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, LOGO_FADE_DURATION)
	tween.tween_interval(LOGO_HOLD_DURATION)
	tween.tween_property(_label, "modulate:a", 0.0, LOGO_FADE_DURATION)
	tween.finished.connect(_advance_page)


func _input(event: InputEvent) -> void:
	if _logo_first and _page_index == 0:
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_advance_page()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance_page()


func _advance_page() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		_finish()
		return
	_show_current_page()


func _finish() -> void:
	sequence_finished.emit()
	queue_free()
