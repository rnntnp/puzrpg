class_name MergeGame
extends Node2D

signal game_over
signal merge_attack_requested(damage: int, combo_count: int, base_points: int)
signal ball_dropped

const BallScene = preload("res://scenes/merge_ball.tscn")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const DANGER_LINE_Y := 150.0
const DROP_GRACE_DURATION := 1.2
const OVERFLOW_DURATION := 0.8
const COMBO_SETTLE_MSEC := 500
const COMBO_MAX_WAIT_MSEC := 4000
const MERGE_ATTACK_DELAY := 0.25
const MERGE_PUSH_RADIUS := 260.0

@onready var balls: Node2D = $Balls
@onready var preview_holder: Node2D = $PreviewHolder
@onready var next_preview_holder: Node2D = $NextPreviewHolder
@onready var guide_line: Line2D = $GuideLine
@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $DropTimerLabel
@onready var combo_label: Label = $ComboLabel
@onready var autoplay_bot = $MergeAutoplayBot
@onready var merge_hit_stop = $MergeHitStop
var current_level := 0
var next_level := 0
var score := 0
var can_drop := true
var is_aiming := false
var aim_x := 360.0
var preview_ball
var next_preview_ball
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
var drop_sequence_active := false
var combo_count := 0
var combo_points := 0
var last_merge_msec := 0
var combo_effect_tween: Tween

func _ready() -> void:
	autoplay_bot.set_enabled(OS.is_debug_build() and GameSession.developer_autoplay_enabled)
	_reset_ball_queue()

func can_accept_autoplay_drop() -> bool:
	return can_drop and not input_locked and not is_game_over

func autoplay_drop_at(x_position: float) -> void:
	if can_accept_autoplay_drop():
		aim_x = clampf(x_position, 38.0, 682.0)
		_update_preview_position()
		_drop_ball(aim_x)

func get_active_balls() -> Array:
	return balls.get_children()

func get_current_ball_level() -> int:
	return current_level

func configure(
	time_limit: float,
	max_ball_level: int,
	physics_speed: float = 1.0,
	push_force: float = 90.0,
	hit_stop_time_scale: float = 0.25,
	hit_stop_duration: float = 0.12
) -> void:
	auto_drop_enabled = time_limit >= 0.0
	drop_time_limit = maxf(0.0, time_limit)
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	max_level_index = clampi(max_ball_level - 1, 0, BallCatalogClass.get_max_level_index())
	physics_speed_multiplier = clampf(physics_speed, 0.5, 3.0)
	merge_push_force = maxf(0.0, push_force)
	merge_hit_stop.configure(hit_stop_time_scale, hit_stop_duration)
	_reset_ball_queue()

func _process(delta: float) -> void:
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
		if local.y < 0.0 or local.y > 830.0 or not can_drop:
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
	var margin := 38.0
	if is_instance_valid(preview_ball):
		margin = maxf(margin, preview_ball.get_radius() + 12.0)
	aim_x = clampf(local.x, margin, 720.0 - margin)
	_update_preview_position()

func _update_preview_position() -> void:
	guide_line.points = PackedVector2Array([Vector2(aim_x, 86.0), Vector2(aim_x, 825.0)])
	if is_instance_valid(preview_ball):
		preview_ball.position = Vector2(aim_x, 60.0)

func _drop_ball(x: float) -> void:
	if input_locked or is_game_over:
		return
	can_drop = false
	_update_drop_preview_visibility()
	is_aiming = false
	drop_sequence_active = true
	combo_count = 0
	combo_points = 0
	last_merge_msec = Time.get_ticks_msec()
	drop_grace_remaining = DROP_GRACE_DURATION
	_spawn_ball(Vector2(x, 60.0), current_level)
	ball_dropped.emit()
	_advance_ball_queue()
	_finish_drop_sequence()

func _finish_drop_sequence() -> void:
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
	drop_sequence_active = false
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	if not input_locked and not is_game_over:
		can_drop = true
	_update_drop_preview_visibility()

func _spawn_ball(at: Vector2, level: int):
	if not is_inside_tree() or not is_instance_valid(balls) or balls.is_queued_for_deletion():
		return null
	var ball = BallScene.instantiate()
	balls.add_child(ball)
	ball.position = at
	ball.setup(level, physics_speed_multiplier)
	ball.merge_requested.connect(_on_merge_requested)
	return ball

func _advance_ball_queue() -> void:
	current_level = next_level
	next_level = _random_drop_level()
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
	if is_instance_valid(next_preview_ball):
		next_preview_ball.queue_free()
	preview_ball = BallScene.instantiate()
	preview_holder.add_child(preview_ball)
	preview_ball.position = Vector2(aim_x, 60.0)
	preview_ball.setup(current_level, physics_speed_multiplier)
	preview_ball.lock_for_merge()
	next_preview_ball = BallScene.instantiate()
	next_preview_holder.add_child(next_preview_ball)
	next_preview_ball.scale = Vector2(0.55, 0.55)
	next_preview_ball.setup(next_level, physics_speed_multiplier)
	next_preview_ball.lock_for_merge()

func _on_merge_requested(first, second) -> void:
	if first.merge_locked or second.merge_locked or first.merge_level >= max_level_index:
		return
	merge_hit_stop.play()
	var at: Vector2 = (first.position + second.position) * 0.5
	var level: int = first.merge_level + 1
	first.lock_for_merge()
	second.lock_for_merge()
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
	var merge_damage := _calculate_merge_damage(earned_points, attack_combo_count)
	if attack_combo_count >= 2:
		_show_combo_effect(attack_combo_count, merge_damage)
	_emit_merge_attack_after_delay(merge_damage, attack_combo_count, earned_points)
	print("[MERGE] %d단계 + %d단계 -> %d단계 | 획득=%d | 사이클=%s | 콤보=%d | 누적=%d" % [
		level, level, level + 1, earned_points,
		str(drop_sequence_active), combo_count, combo_points
	])
	call_deferred("_spawn_merged_ball", at, level)
	drop_grace_remaining = maxf(drop_grace_remaining, 0.5)


func _spawn_merged_ball(at: Vector2, level: int) -> void:
	var merged_ball = _spawn_ball(at, level)
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
		if child.position.y - child.get_radius() < DANGER_LINE_Y:
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
	next_preview_holder.visible = false
	game_over.emit()

func set_input_enabled(enabled: bool) -> void:
	input_locked = not enabled
	is_aiming = false
	next_preview_holder.visible = enabled and not is_game_over
	if enabled and not drop_sequence_active and not is_game_over:
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

func _emit_merge_attack_after_delay(damage: int, count: int, base_points: int) -> void:
	await get_tree().create_timer(MERGE_ATTACK_DELAY).timeout
	if not is_inside_tree():
		return
	print("[MERGE ATTACK REQUEST] 콤보=%d | 기본=%d | 피해=%d" % [count, base_points, damage])
	merge_attack_requested.emit(damage, count, base_points)

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
