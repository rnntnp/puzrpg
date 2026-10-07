extends "res://scripts/gimmicks/visuals/contact_stop_launcher.gd"

var direction := Vector2.UP
var flight_velocity_integrator := Callable()
var prediction_step_seconds := 0.0
var throw_power := 0.45
var flying_balls: Dictionary = {}
var landing_position := Vector2.ZERO
var guide_has_contact := false
var guide_preview_id := 0
var guide_points := PackedVector2Array()
var saved_left_material: PhysicsMaterial
var saved_right_material: PhysicsMaterial
var walls_restored := false
var saved_guide_gradient: Gradient
var guide_length := 0.0
var guide_fade_start := -1.0
var guide_end_alpha := 1.0
var aim_pointer := -2 # -2: none, -1: mouse, otherwise touch index.
var mouse_release_pending := false
var input_trace: Array[Dictionary] = []
var trace_last_mouse_mask := -1


func configure(target: MergeGame, config: Resource) -> void:
	saved_guide_gradient = target.guide_line.gradient
	saved_left_material = target.left_wall.physics_material_override
	saved_right_material = target.right_wall.physics_material_override
	var material := PhysicsMaterial.new()
	material.bounce = 1.0
	material.friction = 0.0
	target.left_wall.physics_material_override = material
	target.right_wall.physics_material_override = material
	super.configure(target, config)
	if OS.is_debug_build():
		game.ball_dropped.connect(_trace_ball_launch)
		_trace_input("configured")
	else:
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_trace_input("raw_input", {"event": event.as_text(), "device": event.device})
	elif event is InputEventMouseMotion:
		var mask := int(event.button_mask)
		if mask != trace_last_mouse_mask:
			trace_last_mouse_mask = mask
			_trace_input("mouse_motion_mask", {"mask": mask})


func _trace_input(kind: String, details: Dictionary = {}) -> void:
	if not OS.is_debug_build() or not is_instance_valid(game):
		return
	var entry := {
		"kind": kind, "time_msec": Time.get_ticks_msec(),
		"mouse_held": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"focused": DisplayServer.window_is_focused(),
		"dragging": dragging, "pointer": aim_pointer,
		"release_pending": mouse_release_pending,
		"can_drop": game.can_drop, "input_locked": game.input_locked,
		"ordinary_input_enabled": game.is_processing_unhandled_input(),
		"auto_drop_enabled": game.auto_drop_enabled,
		"autoplay_enabled": game.autoplay_bot.enabled if is_instance_valid(game.autoplay_bot) else false,
	}
	entry.merge(details)
	input_trace.append(entry)
	if input_trace.size() > 80:
		input_trace.pop_front()


func _trace_ball_launch() -> void:
	_trace_input("ball_launched", {"stack": get_stack(), "sequence": game.drop_sequence_id})
	var path := "user://stage55_input_trace.jsonl"
	# Keep a bounded, silent diagnostic file; never add text to the game UI.
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		return
	if file.get_length() > 2097152:
		file.close()
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return
	file.seek_end()
	file.store_line(JSON.stringify({"launched_at": Time.get_datetime_string_from_system(), "trace": input_trace}))


func _spawn_position() -> Vector2:
	var at := super._spawn_position()
	at.x = (game.board_inner_left + game.board_inner_right) * 0.5
	return at


func configure_active_balls() -> void:
	super.configure_active_balls()
	for ball_id in flying_balls.keys():
		var flight: Dictionary = flying_balls[ball_id]
		if not is_instance_valid(flight.ball):
			flying_balls.erase(ball_id)
			continue
		var ball: MergeBall = flight.ball
		if ball.merge_locked:
			_finish_flight(ball)
			continue
		_apply_flight_gravity(ball, flight)


func _apply_flight_gravity(ball: MergeBall, flight: Dictionary) -> void:
	ball.gravity_scale = 0.0
	# Use the same gravity magnitude as the board, redirecting only this ball.
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var gravity_magnitude: float = gravity * absf(float(original_ball_state[ball.get_instance_id()].gravity))
	var world_direction: Vector2 = (game.to_global(flight.direction) - game.to_global(Vector2.ZERO)).normalized()
	ball.constant_force = flight.force + world_direction * gravity_magnitude * ball.mass


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(game) or not is_instance_valid(game.preview_ball):
		return
	_update_landing_prediction()
	_update_preview()


func _update_preview() -> void:
	if not is_instance_valid(game.preview_ball):
		return
	var start := _spawn_position()
	game.preview_ball.position = start
	# Hide a stale endpoint for the previous queue item until the next physics query.
	game.guide_line.points = guide_points if guide_preview_id == game.preview_ball.get_instance_id() else PackedVector2Array([start, start])
	game._update_drop_preview_visibility()
	queue_redraw()


func _update_landing_prediction() -> void:
	var at := _spawn_position()
	game.preview_ball.position = at
	guide_points = PackedVector2Array([at])
	guide_has_contact = false
	guide_length = 0.0
	guide_fade_start = -1.0
	guide_end_alpha = 1.0
	var speed: float = lerpf(tuning.minimum_throw_speed, tuning.maximum_throw_speed, throw_power)
	var velocity := direction * speed
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)) * game.physics_speed_multiplier * game.physics_speed_multiplier
	var acceleration := direction * gravity
	var damp: float = game.physics_data.ball_linear_damp if game.physics_data != null else 0.0
	var step: float = maxf(0.001, tuning.guide_step_seconds)
	var prediction_steps: int = maxi(1,tuning.guide_max_steps)
	if prediction_step_seconds>0.0:
		prediction_steps=int(ceil(prediction_steps*step/prediction_step_seconds))
		step=prediction_step_seconds
	var left_limit := game.board_inner_left
	var right_limit := game.board_inner_right
	# Actual compound hitbox horizontal extents; flight rotation is locked.
	for child in game.preview_ball.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null:
			continue
		var rect: Rect2 = child.shape.get_rect()
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var offset: Vector2 = child.transform * corner
			left_limit = maxf(left_limit, game.board_inner_left - offset.x)
			right_limit = minf(right_limit, game.board_inner_right - offset.x)
	var reflections := 0
	for index in prediction_steps:
		if flight_velocity_integrator.is_valid():
			velocity=flight_velocity_integrator.call(velocity,acceleration,damp,step)
		else:
			velocity = (velocity + acceleration * step) * maxf(0.0, 1.0 - damp * step)
		var remaining := step
		# Spend the rest of a step after a bounce instead of losing travel time.
		for bounce_step in 4:
			var motion := velocity * remaining
			var wall_fraction := 1.0
			var reaches_wall := false
			if motion.x < 0.0 and at.x + motion.x <= left_limit:
				wall_fraction = clampf((left_limit - at.x) / motion.x, 0.0, 1.0)
				reaches_wall = true
			elif motion.x > 0.0 and at.x + motion.x >= right_limit:
				wall_fraction = clampf((right_limit - at.x) / motion.x, 0.0, 1.0)
				reaches_wall = true
			var segment := motion * wall_fraction
			if guide_fade_start >= 0.0:
				var fade_remaining := maxf(0.0, tuning.guide_fade_distance - (guide_length - guide_fade_start))
				if segment.length() > fade_remaining:
					segment = segment.normalized() * fade_remaining
					reaches_wall = false
			var fraction := _cast_board_segment(at, segment)
			at += segment * fraction
			guide_length += segment.length() * fraction
			guide_points.append(at)
			if fraction < 1.0:
				guide_has_contact = true
				break
			if not reaches_wall:
				break
			velocity.x = -velocity.x
			acceleration.x = -acceleration.x
			reflections += 1
			if reflections == 2:
				guide_fade_start = guide_length
			remaining *= 1.0 - wall_fraction
			at.x = clampf(at.x, left_limit + 0.01, right_limit - 0.01)
			if reflections >= tuning.guide_max_reflections or remaining <= 0.00001:
				break
		if guide_has_contact or reflections >= tuning.guide_max_reflections or (guide_fade_start >= 0.0 and guide_length - guide_fade_start >= tuning.guide_fade_distance - 0.001):
			break
	landing_position = at
	guide_preview_id = game.preview_ball.get_instance_id()
	_update_guide_fade()


func _update_guide_fade() -> void:
	if guide_fade_start < 0.0 or guide_length <= 0.001:
		game.guide_line.gradient = saved_guide_gradient
		return
	var color := game.guide_line.default_color
	guide_end_alpha = 1.0 - clampf((guide_length - guide_fade_start) / maxf(1.0, tuning.guide_fade_distance), 0.0, 1.0)
	var end_color := color
	end_color.a *= guide_end_alpha
	var gradient := Gradient.new()
	var fade_offset := clampf(guide_fade_start / guide_length, 0.0, 0.9999)
	gradient.offsets = PackedFloat32Array([0.0, fade_offset, 1.0])
	gradient.colors = PackedColorArray([color, color, end_color])
	game.guide_line.gradient = gradient


func _cast_board_segment(start: Vector2, motion: Vector2) -> float:
	var world_motion := game.to_global(start + motion) - game.to_global(start)
	var world_offset := game.to_global(start) - game.to_global(_spawn_position())
	var space := game.get_world_2d().direct_space_state
	var fraction := 1.0
	for child in game.preview_ball.get_children():
		if not child is CollisionShape2D:
			continue
		var collision := child as CollisionShape2D
		if collision.disabled or collision.shape == null or collision.is_queued_for_deletion():
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.transform.origin += world_offset
		query.collision_mask = 1
		query.exclude = [game.preview_ball.get_rid(), game.left_wall.get_rid(), game.right_wall.get_rid()]
		query.margin = tuning.guide_collision_margin
		if not space.intersect_shape(query, 1).is_empty():
			return 0.0
		query.motion = world_motion
		var result := space.cast_motion(query)
		if result.size() == 2:
			fraction = minf(fraction, result[0])
	return fraction

func _unhandled_input(event: InputEvent) -> void:
	# Touch has its own ownership; ignore mouse events synthesized from touch.
	if event.device == -1:
		return
	if not is_instance_valid(game) or game.input_locked or not game.can_drop or game.is_game_over:
		dragging = false
		aim_pointer = -2
		mouse_release_pending = false
		return
	var screen := Vector2.ZERO
	var pressed := false
	var released := false
	var pointer := -2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -1
		screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pointer = event.index
		if event.canceled:
			if aim_pointer == pointer:
				dragging = false
				aim_pointer = -2
			return
		screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		pointer = -1
		if not dragging or aim_pointer != pointer:
			return
		screen = event.position
	elif event is InputEventScreenDrag:
		pointer = event.index
		if not dragging or aim_pointer != pointer:
			return
		screen = event.position
	else:
		return
	var point := game.get_global_transform_with_canvas().affine_inverse() * screen
	if pressed:
		mouse_release_pending = false
		if dragging:
			return
		dragging = game.get_board_inner_bounds().has_point(point)
		aim_pointer = pointer if dragging else -2
	if not dragging or aim_pointer != pointer:
		return
	var aim_vector := point - _spawn_position()
	aim_vector.y = minf(aim_vector.y, -20.0)
	direction = aim_vector.normalized()
	throw_power = clampf(aim_vector.length() / tuning.maximum_drag_distance, 0.0, 1.0)
	get_viewport().set_input_as_handled()
	if released:
		if pointer == -1:
			if not mouse_release_pending:
				mouse_release_pending = true
				_confirm_mouse_release.call_deferred()
			return
		dragging = false
		aim_pointer = -2
		_fire_ball()


func _confirm_mouse_release() -> void:
	# Wait until the event batch has finished before trusting the button state.
	await get_tree().process_frame
	_trace_input("release_confirmation")
	if not mouse_release_pending:
		return
	mouse_release_pending = false
	if _is_mouse_held():
		return
	if not DisplayServer.window_is_focused():
		dragging = false
		aim_pointer = -2
		return
	if not dragging or aim_pointer != -1:
		return
	dragging = false
	aim_pointer = -2
	if is_instance_valid(game) and not game.input_locked and game.can_drop and not game.is_game_over:
		_fire_ball()


func _is_mouse_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_trace_input("focus_out")
		mouse_release_pending = false
		dragging = false
		aim_pointer = -2


func _fire_ball() -> void:
	var speed: float = lerpf(tuning.minimum_throw_speed, tuning.maximum_throw_speed, throw_power)
	var ball := game.launch_player_ball(_spawn_position(), direction * speed)
	if not is_instance_valid(ball):
		return
	configure_active_balls()
	var callback := _on_flight_contact.bind(ball)
	var flight := {"ball": ball, "direction": direction, "force": ball.constant_force, "callback": callback, "lock_rotation": ball.lock_rotation}
	ball.lock_rotation = true
	ball.set_meta("directional_flight",true)
	flying_balls[ball.get_instance_id()] = flight
	ball.body_entered.connect(callback)
	_apply_flight_gravity(ball, flight)
	_update_preview()


func _on_flight_contact(body: Node, ball: MergeBall) -> void:
	if not is_instance_valid(ball):
		return
	if (body == game.left_wall or body == game.right_wall) and flying_balls.has(ball.get_instance_id()):
		var flight: Dictionary = flying_balls[ball.get_instance_id()]
		var reflected_direction: Vector2 = flight.direction
		# Match the wall's elastic velocity reflection. Force the horizontal
		# component inward so duplicate contact events cannot flip it back.
		reflected_direction.x = absf(reflected_direction.x) if body == game.left_wall else -absf(reflected_direction.x)
		flight.direction = reflected_direction
		_apply_flight_gravity(ball, flight)
	else:
		_finish_flight(ball)
	# Side walls reflect flight; other contacts restore upward gravity.
	ball.notify_custom_contact()


func _finish_flight(ball: MergeBall) -> void:
	var ball_id := ball.get_instance_id()
	if not flying_balls.has(ball_id):
		return
	ball.remove_meta("directional_flight")
	var flight: Dictionary = flying_balls[ball_id]
	ball.constant_force = flight.force
	ball.lock_rotation = flight.lock_rotation
	ball.gravity_scale = -absf(float(original_ball_state[ball_id].gravity))
	if ball.body_entered.is_connected(flight.callback):
		ball.body_entered.disconnect(flight.callback)
	flying_balls.erase(ball_id)


func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.preview_ball):
		return
	if not game.can_drop or game.input_locked or game.is_game_over:
		return
	if guide_has_contact and guide_preview_id == game.preview_ball.get_instance_id():
		var marker_color: Color = tuning.landing_marker_color
		marker_color.a *= guide_end_alpha
		draw_arc(landing_position, game.preview_ball.get_radius(), 0.0, TAU, 64, marker_color, 2.0, true)
	var bar := Rect2(_spawn_position() + Vector2(-48.0, 22.0), Vector2(96.0, 5.0))
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * throw_power, bar.size.y)), Color(1.0, 1.0, 1.0, 0.55))


func restore_input() -> void:
	mouse_release_pending = false
	dragging = false
	aim_pointer = -2
	_release_flights()
	_restore_wall_materials()
	if is_instance_valid(game) and is_instance_valid(game.guide_line):
		game.guide_line.gradient = saved_guide_gradient
	super.restore_input()


func _restore_wall_materials() -> void:
	if walls_restored:
		return
	walls_restored = true
	if is_instance_valid(game):
		if is_instance_valid(game.left_wall):
			game.left_wall.physics_material_override = saved_left_material
		if is_instance_valid(game.right_wall):
			game.right_wall.physics_material_override = saved_right_material


func _release_flights() -> void:
	for flight in flying_balls.values():
		if is_instance_valid(flight.ball):
			_finish_flight(flight.ball)
	flying_balls.clear()


func _exit_tree() -> void:
	# Scene exit can bypass the normal enemy-defeat cleanup. Other board
	# children may already be freed, so only touch validated ball references.
	_release_flights()
	_restore_wall_materials()
	for state in original_ball_state.values():
		if is_instance_valid(state.ball):
			state.ball.gravity_scale = state.gravity
	original_ball_state.clear()
