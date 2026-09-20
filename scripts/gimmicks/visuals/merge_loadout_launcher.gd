extends Node2D

var game: MergeGame
var tuning: Resource
var direction := Vector2.UP
var dragging := false
var top_wall: StaticBody2D
var original_ball_state: Dictionary = {}
var original_left_wall_material: PhysicsMaterial
var original_right_wall_material: PhysicsMaterial


func configure(target: MergeGame, config: Resource) -> void:
	game = target
	tuning = config
	_create_top_wall()
	original_left_wall_material = game.left_wall.physics_material_override
	original_right_wall_material = game.right_wall.physics_material_override
	game.left_wall.physics_material_override = _make_wall_material()
	game.right_wall.physics_material_override = _make_wall_material()
	game.set_process_unhandled_input(false)
	game.wait_for_turn_before_next_input = true
	game.suppress_danger_line(999999.0)


func _make_wall_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.bounce = tuning.bottom_up_ball_bounce
	material.friction = tuning.bottom_up_ball_friction
	material.absorbent = false
	material.rough = false
	return material


func _create_top_wall() -> void:
	top_wall = StaticBody2D.new()
	top_wall.name = "ReverseSuikaCeiling"
	top_wall.add_to_group("drop_landing_surface")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(game.board_inner_right - game.board_inner_left, 24.0)
	collision.shape = shape
	top_wall.position = Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.drop_position_y - 18.0)
	top_wall.add_child(collision)
	add_child(top_wall)


func launch_position() -> Vector2:
	var radius := 75.0
	if is_instance_valid(game.preview_ball):
		radius = game.preview_ball.get_radius()
	return Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.board_inner_bottom - radius - 18.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(game):
		return
	game.guide_line.hide()
	game.suppress_danger_line(999999.0)
	_apply_reverse_gravity()
	if is_instance_valid(game.preview_ball):
		game.preview_ball.position = launch_position()
	if game.input_locked or not game.can_drop:
		dragging = false
	queue_redraw()


func _apply_reverse_gravity() -> void:
	for child in game.balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		var ball_id := ball.get_instance_id()
		if not original_ball_state.has(ball_id):
			original_ball_state[ball_id] = {
				"ball": ball,
				"gravity": ball.gravity_scale,
				"linear_damp": ball.linear_damp,
				"angular_damp": ball.angular_damp,
				"material": ball.physics_material_override,
			}
			var material := PhysicsMaterial.new()
			material.bounce = tuning.bottom_up_ball_bounce
			material.friction = tuning.bottom_up_ball_friction
			material.absorbent = false
			material.rough = false
			ball.physics_material_override = material
		ball.gravity_scale = -absf(float(original_ball_state[ball_id].gravity))
		ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		ball.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		ball.linear_damp = tuning.bottom_up_linear_damp
		ball.angular_damp = tuning.bottom_up_angular_damp


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(game) or game.input_locked or not game.can_drop or game.is_game_over:
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
		if not dragging:
			return
		screen = event.position
	else:
		return
	var point := get_global_transform_with_canvas().affine_inverse() * screen
	if pressed:
		dragging = game.get_board_inner_bounds().has_point(point)
	if not dragging:
		return
	var delta := point - launch_position()
	var angle := clampf(
		atan2(delta.x, maxf(20.0, -delta.y)),
		-deg_to_rad(tuning.top_down_max_angle_degrees),
		deg_to_rad(tuning.top_down_max_angle_degrees)
	)
	direction = Vector2(sin(angle), -cos(angle))
	get_viewport().set_input_as_handled()
	if released:
		dragging = false
		var launch_velocity := Vector2(
			direction.x * tuning.bottom_up_launch_speed * tuning.bottom_up_horizontal_force_multiplier,
			direction.y * tuning.bottom_up_launch_speed
		)
		game.launch_player_ball(launch_position(), launch_velocity)


func _draw() -> void:
	if not is_instance_valid(game):
		return
	var divider_y: float = game.board_inner_bottom - tuning.launch_chamber_height
	draw_rect(Rect2(Vector2(game.board_inner_left, divider_y), Vector2(game.board_inner_right - game.board_inner_left, tuning.launch_chamber_height)), Color(0.05, 0.11, 0.16, 0.42), true)
	draw_line(Vector2(game.board_inner_left, divider_y), Vector2(game.board_inner_right, divider_y), Color("ffd66c"), 6.0)
	if not game.can_drop or game.input_locked or game.is_game_over:
		return
	var start := launch_position()
	var tip := start + direction * 190.0
	var color := Color("fff3ab")
	draw_line(start, tip, color, 6.0, true)
	draw_line(tip, tip - direction.rotated(0.5) * 27.0, color, 6.0, true)
	draw_line(tip, tip - direction.rotated(-0.5) * 27.0, color, 6.0, true)
	for step in range(1, 5):
		draw_circle(tip + direction * float(step * 25), 3.0, Color(1, 1, 1, 0.65))


func restore_input() -> void:
	for state in original_ball_state.values():
		var ball: MergeBall = state.ball
		if is_instance_valid(ball):
			ball.gravity_scale = state.gravity
			ball.linear_damp = state.linear_damp
			ball.angular_damp = state.angular_damp
			ball.physics_material_override = state.material
	original_ball_state.clear()
	if is_instance_valid(game):
		game.left_wall.physics_material_override = original_left_wall_material
		game.right_wall.physics_material_override = original_right_wall_material
		game.set_process_unhandled_input(true)
		game.wait_for_turn_before_next_input = false
		game._update_preview_position()
		game._update_drop_preview_visibility()
