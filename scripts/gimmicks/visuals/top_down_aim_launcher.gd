extends Node2D

var game: MergeGame
var tuning: Resource
var direction := Vector2.DOWN
var dragging := false
var original_left_wall_material: PhysicsMaterial
var original_right_wall_material: PhysicsMaterial


func configure(target: MergeGame, config: Resource) -> void:
	game = target
	tuning = config
	original_left_wall_material = game.left_wall.physics_material_override
	original_right_wall_material = game.right_wall.physics_material_override
	game.left_wall.physics_material_override = _make_wall_material()
	game.right_wall.physics_material_override = _make_wall_material()
	game.set_process_unhandled_input(false)
	game.wait_for_turn_before_next_input = true


func _make_wall_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.bounce = tuning.top_down_wall_bounce
	material.friction = tuning.top_down_wall_friction
	material.absorbent = false
	material.rough = false
	return material


func launch_position() -> Vector2:
	return Vector2((game.board_inner_left + game.board_inner_right) * 0.5, game.drop_position_y)


func _process(_delta: float) -> void:
	if not is_instance_valid(game):
		return
	game.guide_line.hide()
	if is_instance_valid(game.preview_ball):
		game.preview_ball.position = launch_position()
	if game.input_locked or not game.can_drop:
		dragging = false
	queue_redraw()


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
		atan2(delta.x, maxf(20.0, delta.y)),
		-deg_to_rad(tuning.top_down_max_angle_degrees),
		deg_to_rad(tuning.top_down_max_angle_degrees)
	)
	direction = Vector2(sin(angle), cos(angle))
	get_viewport().set_input_as_handled()
	if released:
		dragging = false
		var launch_velocity := Vector2(
			direction.x * tuning.top_down_launch_speed * tuning.top_down_horizontal_force_multiplier,
			direction.y * tuning.top_down_launch_speed
		)
		game.launch_player_ball(launch_position(), launch_velocity)


func _draw() -> void:
	if not is_instance_valid(game) or not game.can_drop or game.input_locked or game.is_game_over:
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
	if is_instance_valid(game):
		game.left_wall.physics_material_override = original_left_wall_material
		game.right_wall.physics_material_override = original_right_wall_material
		game.set_process_unhandled_input(true)
		game.wait_for_turn_before_next_input = false
		game._update_preview_position()
		game._update_drop_preview_visibility()
