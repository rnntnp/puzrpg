extends Node2D

var game: MergeGame
var tuning: Resource
var direction := Vector2.UP
var throw_power := 0.45
var dragging := false
var top_wall: StaticBody2D
var launch_divider: StaticBody2D
var original_ball_state: Dictionary = {}
var contact_frames: Dictionary = {}
var original_left_wall_material: PhysicsMaterial
var original_right_wall_material: PhysicsMaterial
var original_turn_max_wait_msec := -1
var original_settled_linear_speed := -1.0
var original_settled_angular_speed := -1.0


func configure(target: MergeGame, config: Resource) -> void:
	game = target
	tuning = config
	_create_boundaries()
	original_left_wall_material = game.left_wall.physics_material_override
	original_right_wall_material = game.right_wall.physics_material_override
	game.left_wall.physics_material_override = _make_material(tuning.ball_bounce, tuning.ball_friction)
	game.right_wall.physics_material_override = _make_material(tuning.ball_bounce, tuning.ball_friction)
	game.set_process_unhandled_input(false)
	game.wait_for_turn_before_next_input = true
	original_turn_max_wait_msec = game.turn_max_wait_msec_override
	original_settled_linear_speed = game.settled_linear_speed_override
	original_settled_angular_speed = game.settled_angular_speed_override
	game.turn_max_wait_msec_override = tuning.turn_max_wait_msec
	game.settled_linear_speed_override = tuning.settled_linear_speed
	game.settled_angular_speed_override = tuning.settled_angular_speed
	game.suppress_danger_line(999999.0)


func _create_boundaries() -> void:
	top_wall = StaticBody2D.new()
	top_wall.name = "FlatFieldTopWall"
	top_wall.add_to_group("drop_landing_surface")
	var top_collision := CollisionShape2D.new()
	var top_shape := RectangleShape2D.new()
	top_shape.size = Vector2(game.board_inner_right - game.board_inner_left, 24.0)
	top_collision.shape = top_shape
	top_wall.position = Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.drop_position_y - 18.0)
	top_wall.add_child(top_collision)
	add_child(top_wall)

	launch_divider = StaticBody2D.new()
	launch_divider.name = "FlatFieldLaunchDivider"
	launch_divider.add_to_group("drop_landing_surface")
	var divider_collision := CollisionShape2D.new()
	var divider_shape := RectangleShape2D.new()
	divider_shape.size = Vector2(game.board_inner_right - game.board_inner_left, 12.0)
	divider_collision.shape = divider_shape
	divider_collision.one_way_collision = true
	divider_collision.one_way_collision_margin = 8.0
	launch_divider.position = Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.board_inner_bottom - tuning.launch_zone_height)
	launch_divider.add_child(divider_collision)
	add_child(launch_divider)


func _make_material(bounce: float, friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = friction
	material.absorbent = false
	material.rough = false
	return material


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
	if is_instance_valid(game.preview_ball):
		game.preview_ball.position = launch_position()
	if game.input_locked or not game.can_drop:
		dragging = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	for child in game.balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		_configure_ball(ball)
		if ball.merge_locked:
			continue
		var speed := ball.linear_velocity.length()
		if speed <= tuning.stop_speed:
			ball.linear_velocity = Vector2.ZERO
			ball.angular_velocity = 0.0
		else:
			ball.linear_velocity = ball.linear_velocity.move_toward(Vector2.ZERO, tuning.ground_deceleration * delta)


func _configure_ball(ball: MergeBall) -> void:
	var ball_id := ball.get_instance_id()
	if original_ball_state.has(ball_id):
		ball.gravity_scale = 0.0
		return
	var callback := _on_ball_contact.bind(ball)
	original_ball_state[ball_id] = {
		"ball": ball,
		"gravity": ball.gravity_scale,
		"linear_damp": ball.linear_damp,
		"angular_damp": ball.angular_damp,
		"material": ball.physics_material_override,
		"callback": callback,
	}
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = tuning.angular_damp
	ball.physics_material_override = _make_material(tuning.ball_bounce, tuning.ball_friction)
	ball.body_entered.connect(callback)


func _on_ball_contact(body: Node, ball: MergeBall) -> void:
	if not is_instance_valid(ball):
		return
	if body is MergeBall:
		var other := body as MergeBall
		var low_id := mini(ball.get_instance_id(), other.get_instance_id())
		var high_id := maxi(ball.get_instance_id(), other.get_instance_id())
		var key := "%d:%d" % [low_id, high_id]
		var frame := Engine.get_physics_frames()
		if int(contact_frames.get(key, -1)) == frame:
			return
		contact_frames[key] = frame
		call_deferred("_soften_pair", ball, other)
	else:
		call_deferred("_soften_wall_contact", ball)


func _soften_pair(first: MergeBall, second: MergeBall) -> void:
	if is_instance_valid(first):
		first.linear_velocity *= tuning.collision_velocity_retention
	if is_instance_valid(second):
		second.linear_velocity *= tuning.collision_velocity_retention


func _soften_wall_contact(ball: MergeBall) -> void:
	if is_instance_valid(ball):
		ball.linear_velocity *= tuning.wall_velocity_retention


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
	var aim_vector := point - launch_position()
	aim_vector.y = minf(aim_vector.y, -20.0)
	direction = aim_vector.normalized()
	throw_power = clampf(aim_vector.length() / tuning.maximum_drag_distance, 0.0, 1.0)
	get_viewport().set_input_as_handled()
	if released:
		dragging = false
		var speed: float = lerpf(tuning.minimum_throw_speed, tuning.maximum_throw_speed, throw_power)
		game.launch_player_ball(launch_position(), direction * speed)


func _draw() -> void:
	if not is_instance_valid(game):
		return
	var divider_y: float = game.board_inner_bottom - tuning.launch_zone_height
	draw_rect(Rect2(Vector2(game.board_inner_left, divider_y), Vector2(game.board_inner_right - game.board_inner_left, tuning.launch_zone_height)), Color(0.08, 0.17, 0.10, 0.50), true)
	draw_line(Vector2(game.board_inner_left, divider_y), Vector2(game.board_inner_right, divider_y), Color("f4e9a7"), 3.0)
	if not game.can_drop or game.input_locked or game.is_game_over:
		return
	var start := launch_position()
	var length := lerpf(80.0, 230.0, throw_power)
	var tip := start + direction * length
	var color := Color("8de38d").lerp(Color("ffd36a"), throw_power)
	draw_line(start, tip, color, 6.0, true)
	draw_line(tip, tip - direction.rotated(0.5) * 25.0, color, 6.0, true)
	draw_line(tip, tip - direction.rotated(-0.5) * 25.0, color, 6.0, true)
	var bar := Rect2(start + Vector2(-68.0, 40.0), Vector2(136.0, 11.0))
	draw_rect(bar, Color(0.04, 0.08, 0.05, 0.82), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * throw_power, bar.size.y)), color, true)


func restore_input() -> void:
	for state in original_ball_state.values():
		var ball: MergeBall = state.ball
		if not is_instance_valid(ball):
			continue
		var callback: Callable = state.callback
		if ball.body_entered.is_connected(callback):
			ball.body_entered.disconnect(callback)
		ball.gravity_scale = state.gravity
		ball.linear_damp = state.linear_damp
		ball.angular_damp = state.angular_damp
		ball.physics_material_override = state.material
	original_ball_state.clear()
	contact_frames.clear()
	if is_instance_valid(game):
		game.left_wall.physics_material_override = original_left_wall_material
		game.right_wall.physics_material_override = original_right_wall_material
		game.set_process_unhandled_input(true)
		game.wait_for_turn_before_next_input = false
		game.turn_max_wait_msec_override = original_turn_max_wait_msec
		game.settled_linear_speed_override = original_settled_linear_speed
		game.settled_angular_speed_override = original_settled_angular_speed
		game._update_preview_position()
		game._update_drop_preview_visibility()
