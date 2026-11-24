extends Node2D
var game: MergeGame
var soft_layer: Node2D
var enabled := true
var color := Color(0.1, 1.0, 0.85, 0.95)
var deformation_label: Label

func configure(board: MergeGame, solver: Node2D, settings: Resource, backend: String) -> void:
	game = board
	soft_layer = solver
	enabled = settings.show_soft_debug
	color = settings.soft_debug_color
	z_as_relative = false
	z_index = 100
	var hud := CanvasLayer.new()
	hud.layer = 100
	add_child(hud)
	var checkbox := CheckBox.new()
	checkbox.text = "실제 충돌체 표시"
	checkbox.position = Vector2(10, 8)
	checkbox.add_theme_font_size_override("font_size", 20)
	checkbox.custom_minimum_size = Vector2(230, 44)
	checkbox.button_pressed = enabled
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_on_toggled)
	hud.add_child(checkbox)
	var label := Label.new()
	label.text = backend
	label.position = Vector2(10, 52)
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
func _on_toggled(value: bool) -> void:
	enabled = value
	queue_redraw()

func _process(_delta: float) -> void:
	if enabled: queue_redraw()

func _draw() -> void:
	if not enabled or not is_instance_valid(soft_layer): return
	var screen_scale := maxf(0.001, get_global_transform_with_canvas().x.length())
	for state: Dictionary in soft_layer.states.values():
		if not is_instance_valid(state.ball) or state.ball.merge_locked: continue
		var outline: PackedVector2Array = soft_layer._surface(state)
		if outline.size() < 3: continue
		for i in outline.size(): outline[i] = to_local(outline[i])
		for point in outline: draw_circle(point, 2.0 / screen_scale, color)
		outline.append(outline[0])
		draw_polyline(outline, color, 1.5 / screen_scale, true)
