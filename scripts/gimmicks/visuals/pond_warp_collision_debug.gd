extends "res://scripts/gimmicks/visuals/compound_pond_collision_debug.gd"
## Read-only outlines: cyan = native shapes, magenta = merge query polygon.
const MergeContact = preload("res://scripts/gimmicks/visuals/pond_warp_merge_contact.gd")
var warp_layer: Node2D
var debug_enabled := true

func configure(board: MergeGame, settings: Resource) -> void:
	super.configure(board, settings)
	debug_enabled = settings.show_warp_collision_debug
	var hud := CanvasLayer.new()
	hud.name = "CollisionDebugHUD"
	hud.layer = 100
	add_child(hud)
	var checkbox := CheckBox.new()
	checkbox.name = "CollisionDebugToggle"
	checkbox.text = "충돌체 표시"
	checkbox.position = Vector2(10, 8)
	checkbox.custom_minimum_size = Vector2(170, 44)
	checkbox.add_theme_font_size_override("font_size", 20)
	checkbox.button_pressed = debug_enabled
	checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_on_debug_toggled)
	hud.add_child(checkbox)

func _on_debug_toggled(enabled: bool) -> void:
	debug_enabled = enabled
	queue_redraw()

func _process(_delta: float) -> void:
	if debug_enabled: queue_redraw()

func _draw_body(ball: MergeBall, color: Color) -> void:
	var canvas_scale := maxf(0.0001, get_global_transform_with_canvas().x.length())
	for child in ball.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		var outline := _outline(child.shape)
		if outline.size() < 3: continue
		var to_overlay: Transform2D = global_transform.affine_inverse() * child.global_transform
		for i in outline.size(): outline[i] = to_overlay * outline[i]
		outline.append(outline[0])
		draw_polyline(outline, color, tuning.warp_collision_debug_line_width / canvas_scale, true)

func _draw() -> void:
	if not is_instance_valid(game) or tuning == null or not debug_enabled: return
	for ball in game.get_active_balls():
		if ball is MergeBall and not ball.merge_locked and not ball.is_queued_for_deletion():
			_draw_body(ball, tuning.warp_collision_debug_color)
	if not is_instance_valid(warp_layer): return
	var to_overlay := global_transform.affine_inverse() * game.global_transform
	var canvas_scale := maxf(0.0001, get_global_transform_with_canvas().x.length())
	for state: Dictionary in warp_layer.states.values():
		if not is_instance_valid(state.ball) or state.ball.merge_locked or not state.has("merge_outline"): continue
		var outline: PackedVector2Array = MergeContact._outline(state)
		if outline.size() < 3: continue
		for i in outline.size(): outline[i] = to_overlay * outline[i]
		outline.append(outline[0])
		draw_polyline(outline, tuning.merge_debug_color, tuning.warp_collision_debug_line_width / canvas_scale, true)
	var label_position: Vector2 = to_overlay * (game.get_playable_board_bounds().position + Vector2(8, 22))
	draw_string(ThemeDB.fallback_font, label_position, "PHYSICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tuning.warp_collision_debug_color)
	draw_string(ThemeDB.fallback_font, label_position + Vector2(100, 0), "MERGE (WARP)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tuning.merge_debug_color)
