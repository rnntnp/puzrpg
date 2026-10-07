extends Node2D

var game: MergeGame
var tuning: Resource
var ceiling: StaticBody2D
var original_ball_state: Dictionary = {}
var original_danger_y := 0.0
var original_danger_direction := 1.0
var original_input_enabled := true
var original_guide_visible := true
var dragging := false


func configure(target: MergeGame, config: Resource) -> void:
	game = target
	tuning = config
	original_input_enabled = game.is_processing_unhandled_input()
	original_guide_visible = game.guide_line.visible
	original_danger_y = game.danger_line_y
	original_danger_direction = game.danger_height_direction
	ceiling = StaticBody2D.new()
	ceiling.name = "ReverseDropCeiling"
	ceiling.add_to_group("drop_landing_surface")
	ceiling.physics_material_override = game.floor_body.physics_material_override
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(game.board_inner_right - game.board_inner_left, tuning.ceiling_thickness)
	collision.shape = shape
	ceiling.position = Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.drop_position_y - tuning.ceiling_thickness * 0.5)
	ceiling.add_child(collision)
	add_child(ceiling)
	game.danger_height_direction = -1.0
	game.danger_line_y = game.board_inner_bottom - (game.board_inner_bottom - game.drop_position_y) * game.danger_line_height_ratio
	game.danger_line.configure(game.board_inner_left, game.board_inner_right, game.danger_line_y)
	game.set_process_unhandled_input(false)
	configure_active_balls()
	_update_preview()


func configure_active_balls() -> void:
	if not is_instance_valid(game):
		return
	for child in game.balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		var ball_id := ball.get_instance_id()
		if not original_ball_state.has(ball_id):
			original_ball_state[ball_id] = {"ball": ball, "gravity": ball.gravity_scale}
		ball.gravity_scale = -absf(float(original_ball_state[ball_id].gravity))


func _physics_process(_delta: float) -> void:
	configure_active_balls()


func _process(_delta: float) -> void:
	if not is_instance_valid(game):
		return
	_update_preview()
	if game.input_locked or not game.can_drop or game.is_game_over:
		dragging = false


func _spawn_position() -> Vector2:
	var radius := 75.0
	if is_instance_valid(game.preview_ball):
		radius = game.preview_ball.get_radius()
	return Vector2(game.aim_x, game.board_inner_bottom - radius - tuning.spawn_floor_clearance)


func _update_preview() -> void:
	game.guide_line.points = PackedVector2Array([
		_spawn_position(),
		Vector2(game.aim_x, game.drop_position_y + MergeGame.GUIDE_BOTTOM_MARGIN),
	])
	game._update_drop_preview_visibility()
	if is_instance_valid(game.preview_ball):
		game.preview_ball.position = _spawn_position()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(game) or game.input_locked or game.is_game_over:
		return
	var screen := Vector2.ZERO
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		screen = event.position
	else:
		return
	var point := game.get_global_transform_with_canvas().affine_inverse() * screen
	game.aim_x = game._clamp_aim_x(point.x)
	_update_preview()
	if pressed:
		dragging = game.can_drop and game.get_board_inner_bounds().has_point(point)
	if released:
		var should_drop := dragging and game.can_drop
		dragging = false
		if should_drop:
			game.launch_player_ball(_spawn_position(), Vector2.ZERO)
			_update_preview()
	if dragging or released:
		get_viewport().set_input_as_handled()


func restore_input() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	for state in original_ball_state.values():
		# A merged ball can already be freed; validate before typed assignment.
		if not is_instance_valid(state.ball):
			continue
		var ball: MergeBall = state.ball
		ball.gravity_scale = state.gravity
	original_ball_state.clear() 
	if is_instance_valid(game):
		game.danger_height_direction = original_danger_direction
		game.danger_line_y = original_danger_y
		game.danger_line.configure(game.board_inner_left, game.board_inner_right, original_danger_y)
		game.set_process_unhandled_input(original_input_enabled)
		game.guide_line.visible = original_guide_visible
		game._update_preview_position()
		game._update_drop_preview_visibility()
