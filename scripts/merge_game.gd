class_name MergeGame
extends Node2D

signal game_over
signal merge_attack_requested(
	damage: int,
	combo_count: int,
	base_points: int,
	origin: Vector2,
	ball_level: int
)
signal ball_dropped
signal ingestion_target_replaced(ball: MergeBall)
signal merge_completed(merged_ball: MergeBall)

const BallScene = preload("res://scenes/merge_ball.tscn")
const MergeBurstEffectScene = preload("res://scenes/merge_burst_effect.tscn")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const MergePhysicsDataClass = preload("res://scripts/merge_physics_data.gd")
const DangerLineClass = preload("res://scripts/danger_line.gd")
const NextPreviewPanelClass = preload("res://scripts/next_preview_panel.gd")
const DROP_HEIGHT_RATIO := 0.1655
const DANGER_LINE_HEIGHT_RATIO := 0.2720
const DANGER_LINE_REVEAL_FILL_RATIO := 0.8
const GUIDE_BOTTOM_MARGIN := 21.0
const DROP_GRACE_DURATION := 1.2
const OVERFLOW_DURATION := 0.8
const COMBO_SETTLE_MSEC := 500
const COMBO_MAX_WAIT_MSEC := 4000
const MERGE_ATTACK_DELAY := 0.25
const MERGE_PUSH_RADIUS := 260.0

@onready var balls: Node2D = $Balls
@onready var preview_holder: Node2D = $PreviewHolder
@onready var next_panel: NextPreviewPanelClass = $NextPanel
@onready var guide_line: Line2D = $GuideLine
@onready var danger_line: DangerLineClass = $DropLine
@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $DropTimerLabel
@onready var combo_label: Label = $ComboLabel
@onready var autoplay_bot = $MergeAutoplayBot
@onready var merge_hit_stop = $MergeHitStop
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var floor_body: StaticBody2D = $Floor
@onready var left_wall_shape: CollisionShape2D = $LeftWall/CollisionShape2D
@onready var right_wall_shape: CollisionShape2D = $RightWall/CollisionShape2D
@onready var floor_shape: CollisionShape2D = $Floor/CollisionShape2D
@export var physics_data: MergePhysicsDataClass
var current_level := 0
var next_level := 0
var score := 0
var can_drop := true
var is_aiming := false
var aim_x := 360.0
var preview_ball
var drop_grace_remaining := 0.0
var overflow_time := 0.0
var is_game_over := false
var input_locked := false
var drop_time_limit := 5.0
var drop_time_remaining := 5.0
var auto_drop_enabled := true
var max_level_index: int = BallCatalogClass.get_max_level_index()
var physics_speed_multiplier := 1.0
var merge_push_force := 90.0
var chain_merge_delay := 0.1
var drop_sequence_active := false
var drop_sequence_id := 0
var combo_count := 0
var combo_points := 0
var last_merge_msec := 0
var combo_effect_tween: Tween
var queued_levels: Array[int] = []
var next_merge_resolution_msec := 0
var dropped_ball_has_landed := false
var board_inner_left := 96.0
var board_inner_right := 624.0
var board_inner_top := 0.0
var board_inner_bottom := 846.0
var drop_position_y := 140.0
var danger_line_y := 230.0

func _ready() -> void:
	_sync_board_geometry_from_collisions()
	_apply_physics_data()
	autoplay_bot.set_enabled(OS.is_debug_build() and GameSession.developer_autoplay_enabled)
	_reset_ball_queue()


func _sync_board_geometry_from_collisions() -> void:
	var left_rect := _collision_rect_in_local_space(left_wall_shape)
	var right_rect := _collision_rect_in_local_space(right_wall_shape)
	var floor_rect := _collision_rect_in_local_space(floor_shape)

	board_inner_left = left_rect.end.x
	board_inner_right = right_rect.position.x
	board_inner_top = maxf(left_rect.position.y, right_rect.position.y)
	board_inner_bottom = floor_rect.position.y

	if board_inner_right <= board_inner_left or board_inner_bottom <= board_inner_top:
		push_error("Drop-zone collision shapes do not form a valid play area.")
		return

	var board_height := board_inner_bottom - board_inner_top
	drop_position_y = board_inner_top + board_height * DROP_HEIGHT_RATIO
	danger_line_y = board_inner_top + board_height * DANGER_LINE_HEIGHT_RATIO
	aim_x = (board_inner_left + board_inner_right) * 0.5
	danger_line.configure(board_inner_left, board_inner_right, danger_line_y)
	_update_preview_position()


func _collision_rect_in_local_space(collision: CollisionShape2D) -> Rect2:
	if not collision.shape is RectangleShape2D:
		push_error("Drop-zone collision shape must be RectangleShape2D: %s" % collision.get_path())
		return Rect2()
	var rectangle := collision.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var relative_transform := global_transform.affine_inverse() * collision.global_transform
	var corners := [
		relative_transform * Vector2(-half_size.x, -half_size.y),
		relative_transform * Vector2(half_size.x, -half_size.y),
		relative_transform * Vector2(half_size.x, half_size.y),
		relative_transform * Vector2(-half_size.x, half_size.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _apply_physics_data() -> void:
	if physics_data == null:
		return
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = physics_data.wall_friction
	wall_material.bounce = physics_data.wall_bounce
	left_wall.physics_material_override = wall_material
	right_wall.physics_material_override = wall_material
	var floor_material := PhysicsMaterial.new()
	floor_material.friction = physics_data.floor_friction
	floor_material.bounce = physics_data.floor_bounce
	floor_body.physics_material_override = floor_material

func can_accept_autoplay_drop() -> bool:
	return can_drop and not input_locked and not is_game_over

func autoplay_drop_at(x_position: float) -> void:
	if can_accept_autoplay_drop():
		aim_x = _clamp_aim_x(x_position)
		_update_preview_position()
		_drop_ball(aim_x)

func get_active_balls() -> Array:
	return balls.get_children()

func get_current_ball_level() -> int:
	return current_level


func get_board_inner_bounds() -> Rect2:
	return Rect2(
		Vector2(board_inner_left, board_inner_top),
		Vector2(board_inner_right - board_inner_left, board_inner_bottom - board_inner_top)
	)


func wait_until_board_settled(max_wait_seconds := 4.0) -> void:
	var started := Time.get_ticks_msec()
	while is_inside_tree():
		var quiet := Time.get_ticks_msec() - last_merge_msec >= COMBO_SETTLE_MSEC
		if quiet and not _has_moving_balls():
			return
		if Time.get_ticks_msec() - started >= roundi(max_wait_seconds * 1000.0):
			return
		await get_tree().physics_frame


func consume_ball(ball: MergeBall) -> void:
	if not is_instance_valid(ball) or ball.merge_locked:
		return
	ball.set_ingestion_marked(false)
	ball.lock_for_merge()
	ball.queue_free()


func animate_ball_consumption(ball: MergeBall, target_global_position: Vector2, duration := 0.55) -> bool:
	if not is_instance_valid(ball) or ball.merge_locked:
		return false
	ball.set_ingestion_marked(false)
	ball.lock_for_merge()
	ball.z_index = 200
	var start_position := ball.global_position
	var control_position := (start_position + target_global_position) * 0.5 + Vector2(0.0, -90.0)
	var start_scale := ball.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(weight: float) -> void:
		if is_instance_valid(ball):
			var first_leg := start_position.lerp(control_position, weight)
			var second_leg := control_position.lerp(target_global_position, weight)
			ball.global_position = first_leg.lerp(second_leg, weight)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ball, "scale", start_scale * 0.12, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ball, "rotation", ball.rotation + TAU * 0.8, duration)
	await tween.finished
	if not is_instance_valid(ball):
		return false
	ball.queue_free()
	return true


func insert_ball_after_current(level: int) -> void:
	var previous_next := next_level
	next_level = clampi(level, 0, max_level_index)
	queued_levels.push_front(previous_next)
	_refresh_preview()

func configure(
	time_limit: float,
	max_ball_level: int,
	physics_speed: float = 1.0,
	push_force: float = 90.0,
	hit_stop_time_scale: float = 0.25,
	hit_stop_duration: float = 0.12,
	chain_delay: float = 0.1
) -> void:
	auto_drop_enabled = time_limit >= 0.0
	drop_time_limit = maxf(0.0, time_limit)
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	max_level_index = clampi(max_ball_level - 1, 0, BallCatalogClass.get_max_level_index())
	physics_speed_multiplier = clampf(physics_speed, 0.5, 3.0)
	merge_push_force = maxf(0.0, push_force)
	merge_hit_stop.configure(hit_stop_time_scale, hit_stop_duration)
	chain_merge_delay = maxf(0.0, chain_delay)
	_reset_ball_queue()

func _process(delta: float) -> void:
	danger_line.visible = _should_show_danger_line()
	if is_game_over:
		return
	if auto_drop_enabled and can_drop and not input_locked:
		drop_time_remaining = maxf(0.0, drop_time_remaining - delta)
		timer_label.text = "자동 낙하 %.1f초" % drop_time_remaining
		if drop_time_remaining <= 0.0:
			_drop_ball(aim_x)
	if drop_grace_remaining > 0.0:
		drop_grace_remaining -= delta
		overflow_time = 0.0
		return
	if _has_ball_over_danger_line():
		overflow_time += delta
		if overflow_time >= OVERFLOW_DURATION:
			_trigger_game_over()
	else:
		overflow_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or is_game_over:
		return
	if event is InputEventMouseMotion:
		_update_aim(event.position)
	elif event is InputEventScreenDrag:
		_update_aim(event.position)
	elif event is InputEventScreenTouch:
		_handle_pointer_button(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_button(event.position, event.pressed)

func _handle_pointer_button(screen_position: Vector2, pressed: bool) -> void:
	var local := to_local(screen_position)
	if pressed:
		if local.y < board_inner_top or local.y > board_inner_bottom or not can_drop:
			return
		is_aiming = true
		_update_aim(screen_position)
		get_viewport().set_input_as_handled()
	elif is_aiming:
		is_aiming = false
		_update_aim(screen_position)
		if can_drop:
			_drop_ball(aim_x)
		get_viewport().set_input_as_handled()

func _update_aim(screen_position: Vector2) -> void:
	var local := to_local(screen_position)
	aim_x = _clamp_aim_x(local.x)
	_update_preview_position()


func _clamp_aim_x(x_position: float) -> float:
	var radius := 26.0
	if is_instance_valid(preview_ball):
		radius = preview_ball.get_radius()
	return clampf(x_position, board_inner_left + radius, board_inner_right - radius)

func _update_preview_position() -> void:
	guide_line.points = PackedVector2Array([
		Vector2(aim_x, drop_position_y),
		Vector2(aim_x, board_inner_bottom - GUIDE_BOTTOM_MARGIN),
	])
	if is_instance_valid(preview_ball):
		preview_ball.position = Vector2(aim_x, drop_position_y)

func _drop_ball(x: float) -> void:
	if input_locked or is_game_over:
		return
	can_drop = false
	_update_drop_preview_visibility()
	is_aiming = false
	drop_sequence_active = true
	dropped_ball_has_landed = false
	drop_sequence_id += 1
	var current_sequence_id := drop_sequence_id
	combo_count = 0
	combo_points = 0
	last_merge_msec = Time.get_ticks_msec()
	next_merge_resolution_msec = last_merge_msec
	drop_grace_remaining = DROP_GRACE_DURATION
	_spawn_ball(Vector2(x, drop_position_y), current_level, current_sequence_id)
	ball_dropped.emit()
	_advance_ball_queue()
	_finish_drop_sequence(current_sequence_id)

func _finish_drop_sequence(sequence_id: int) -> void:
	var sequence_started_msec := Time.get_ticks_msec()
	await get_tree().physics_frame
	while is_inside_tree():
		var now := Time.get_ticks_msec()
		var merge_is_quiet := now - last_merge_msec >= COMBO_SETTLE_MSEC
		var exceeded_max_wait := now - sequence_started_msec >= COMBO_MAX_WAIT_MSEC
		if (merge_is_quiet and not _has_moving_balls()) or exceeded_max_wait:
			break
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	if sequence_id != drop_sequence_id:
		return
	drop_sequence_active = false
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()

func _spawn_ball(at: Vector2, level: int, contact_sequence_id: int = -1):
	if not is_inside_tree() or not is_instance_valid(balls) or balls.is_queued_for_deletion():
		return null
	var ball = BallScene.instantiate()
	ball.position = at
	# CCD가 기본 위치 (0, 0)에서 생성 위치까지의 이동을 벽 관통으로 오인하지 않도록
	# 씬 트리에 추가하기 전에 초기 위치를 지정한다.
	ball.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	balls.add_child(ball)
	ball.setup(level, physics_speed_multiplier)
	if physics_data != null:
		ball.linear_damp = physics_data.ball_linear_damp
		ball.angular_damp = physics_data.ball_angular_damp
	_enable_ball_ccd_after_spawn(ball)
	var global_left := to_global(Vector2(board_inner_left, 0.0)).x
	var global_right := to_global(Vector2(board_inner_right, 0.0)).x
	var global_bottom := to_global(Vector2(0.0, board_inner_bottom)).y
	ball.set_play_area_bounds(global_left, global_right, global_bottom)
	ball.merge_requested.connect(_on_merge_requested)
	if contact_sequence_id >= 0:
		ball.first_contact.connect(_on_dropped_ball_first_contact.bind(contact_sequence_id), CONNECT_ONE_SHOT)
	return ball


func _enable_ball_ccd_after_spawn(ball: RigidBody2D) -> void:
	await get_tree().physics_frame
	if is_instance_valid(ball) and not ball.merge_locked:
		ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE


func _on_dropped_ball_first_contact(_ball: MergeBall, sequence_id: int) -> void:
	if sequence_id != drop_sequence_id or is_game_over:
		return
	dropped_ball_has_landed = true
	if not input_locked:
		can_drop = true
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()

func _advance_ball_queue() -> void:
	current_level = next_level
	next_level = queued_levels.pop_front() if not queued_levels.is_empty() else _random_drop_level()
	_refresh_preview()

func _reset_ball_queue() -> void:
	current_level = _random_drop_level()
	next_level = _random_drop_level()
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	_refresh_preview()

func _random_drop_level() -> int:
	return randi_range(0, mini(4, max_level_index))

func _refresh_preview() -> void:
	if is_instance_valid(preview_ball):
		preview_ball.queue_free()
	preview_ball = BallScene.instantiate()
	preview_holder.add_child(preview_ball)
	preview_ball.position = Vector2(aim_x, drop_position_y)
	preview_ball.setup(current_level, physics_speed_multiplier)
	preview_ball.lock_for_merge()
	next_panel.set_preview_data(BallCatalogClass.get_ball(next_level))

func _on_merge_requested(first, second) -> void:
	if first.merge_locked or second.merge_locked or first.merge_level >= max_level_index:
		return
	var at: Vector2 = (first.position + second.position) * 0.5
	var level: int = first.merge_level + 1
	var carries_ingestion_target: bool = first.ingestion_marked or second.ingestion_marked
	first.lock_for_merge()
	second.lock_for_merge()
	# 연쇄 접촉은 순서를 예약해 하나씩 보여준 뒤 합성한다. 실제 시간 기준이라 FPS와 무관하다.
	if drop_sequence_active and chain_merge_delay > 0.0:
		var now_msec := Time.get_ticks_msec()
		var scheduled_msec := now_msec
		if combo_count > 0:
			scheduled_msec = maxi(now_msec, next_merge_resolution_msec)
		next_merge_resolution_msec = scheduled_msec + roundi(chain_merge_delay * 1000.0)
		var wait_seconds := float(scheduled_msec - now_msec) / 1000.0
		if wait_seconds > 0.0:
			await get_tree().create_timer(wait_seconds, true, false, true).timeout
		if not is_inside_tree() or not is_instance_valid(first) or not is_instance_valid(second):
			return
	merge_hit_stop.play()
	first.queue_free()
	second.queue_free()
	var merged_ball_data: Resource = BallCatalogClass.get_ball(level)
	var earned_points: int = merged_ball_data.merge_score
	score += earned_points
	score_label.text = "점수 %d" % score
	var attack_combo_count := 1
	if drop_sequence_active:
		combo_count += 1
		combo_points += earned_points
		last_merge_msec = Time.get_ticks_msec()
		attack_combo_count = combo_count
	_spawn_merge_burst(at, merged_ball_data, attack_combo_count)
	var merge_damage := _calculate_merge_damage(earned_points, attack_combo_count)
	if attack_combo_count >= 2:
		_show_combo_effect(attack_combo_count, merge_damage)
	_emit_merge_attack_after_delay(merge_damage, attack_combo_count, earned_points, at, level)
	print("[MERGE] %d단계 + %d단계 -> %d단계 | 획득=%d | 사이클=%s | 콤보=%d | 누적=%d" % [
		level, level, level + 1, earned_points,
		str(drop_sequence_active), combo_count, combo_points
	])
	call_deferred("_spawn_merged_ball", at, level, carries_ingestion_target)
	drop_grace_remaining = maxf(drop_grace_remaining, 0.5)


func _spawn_merge_burst(at: Vector2, data: Resource, merge_combo_count: int) -> void:
	var burst = MergeBurstEffectScene.instantiate()
	add_child(burst)
	burst.play(at, data.glow_color, data.get_radius(), merge_combo_count, data.level)


func _spawn_merged_ball(at: Vector2, level: int, carries_ingestion_target: bool = false) -> void:
	var merged_ball = _spawn_ball(at, level)
	if carries_ingestion_target and is_instance_valid(merged_ball):
		merged_ball.set_ingestion_marked(true)
		ingestion_target_replaced.emit(merged_ball)
	if is_instance_valid(merged_ball):
		merge_completed.emit(merged_ball)
	if not is_instance_valid(merged_ball) or merge_push_force <= 0.0:
		return
	_apply_merge_push(at, merged_ball)


func _apply_merge_push(origin: Vector2, merged_ball: MergeBall) -> void:
	for child in balls.get_children():
		if not child is MergeBall or child == merged_ball:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_queued_for_deletion():
			continue
		var offset := ball.position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance >= MERGE_PUSH_RADIUS:
			continue
		var falloff := 1.0 - distance / MERGE_PUSH_RADIUS
		var impulse := offset.normalized() * merge_push_force * falloff * ball.mass
		ball.apply_central_impulse(impulse)

func _has_ball_over_danger_line() -> bool:
	for child in balls.get_children():
		if child.merge_locked:
			continue
		if child.position.y - child.get_radius() < danger_line_y:
			return true
	return false


func _should_show_danger_line() -> bool:
	if is_game_over:
		return false
	var reveal_y := lerpf(board_inner_bottom, danger_line_y, DANGER_LINE_REVEAL_FILL_RATIO)
	for child in balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or not ball.has_landed():
			continue
		if ball.position.y - ball.get_radius() <= reveal_y:
			return true
	return false

func _has_moving_balls() -> bool:
	for child in balls.get_children():
		if child.merge_locked:
			continue
		if not child.sleeping and (child.linear_velocity.length() > 8.0 or absf(child.angular_velocity) > 0.2):
			return true
	return false

func _trigger_game_over() -> void:
	is_game_over = true
	can_drop = false
	_update_drop_preview_visibility()
	next_panel.visible = false
	game_over.emit()

func set_input_enabled(enabled: bool) -> void:
	input_locked = not enabled
	is_aiming = false
	next_panel.visible = enabled and not is_game_over
	if enabled and (dropped_ball_has_landed or not drop_sequence_active) and not is_game_over:
		can_drop = true
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()

func _update_drop_preview_visibility() -> void:
	var should_show := can_drop and not input_locked and not is_game_over
	guide_line.visible = should_show
	preview_holder.visible = should_show

func _calculate_merge_damage(base_points: int, count: int) -> int:
	var multiplier := 1.0 + 0.5 * float(count - 1)
	return roundi(float(base_points) * multiplier)

func _emit_merge_attack_after_delay(
	damage: int,
	count: int,
	base_points: int,
	origin: Vector2,
	ball_level: int
) -> void:
	await get_tree().create_timer(MERGE_ATTACK_DELAY).timeout
	if not is_inside_tree():
		return
	print("[MERGE ATTACK REQUEST] 콤보=%d | 기본=%d | 피해=%d" % [count, base_points, damage])
	merge_attack_requested.emit(damage, count, base_points, to_global(origin), ball_level)

func _show_combo_effect(count: int, damage: int) -> void:
	if combo_effect_tween != null and combo_effect_tween.is_valid():
		combo_effect_tween.kill()
	combo_label.text = "COMBO x%d\nDAMAGE %d" % [count, damage]
	combo_label.visible = true
	combo_label.scale = Vector2(0.6, 0.6)
	combo_label.modulate = Color(1, 1, 1, 0)
	combo_effect_tween = create_tween()
	combo_effect_tween.set_parallel(true)
	combo_effect_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combo_effect_tween.tween_property(combo_label, "modulate", Color.WHITE, 0.15)
	combo_effect_tween.set_parallel(false)
	combo_effect_tween.tween_interval(0.35)
	combo_effect_tween.tween_property(combo_label, "modulate:a", 0.0, 0.22)
	combo_effect_tween.tween_callback(func(): combo_label.visible = false)
