class_name MergeGame
extends Node2D

signal game_over
signal merge_scored(points: int)
signal ball_dropped

const BallScene = preload("res://scenes/merge_ball.tscn")
const ABSOLUTE_MAX_LEVEL := 10
const DANGER_LINE_Y := 150.0
const DROP_GRACE_DURATION := 1.2
const OVERFLOW_DURATION := 0.8

@onready var balls: Node2D = $Balls
@onready var preview_holder: Node2D = $PreviewHolder
@onready var next_preview_holder: Node2D = $NextPreviewHolder
@onready var guide_line: Line2D = $GuideLine
@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $DropTimerLabel
@onready var autoplay_bot = $MergeAutoplayBot
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
var max_level_index := ABSOLUTE_MAX_LEVEL

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

func configure(time_limit: float, max_ball_level: int) -> void:
	auto_drop_enabled = time_limit >= 0.0
	drop_time_limit = maxf(0.0, time_limit)
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	max_level_index = clampi(max_ball_level - 1, 0, ABSOLUTE_MAX_LEVEL)
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
	is_aiming = false
	drop_grace_remaining = DROP_GRACE_DURATION
	_spawn_ball(Vector2(x, 60.0), current_level)
	ball_dropped.emit()
	_advance_ball_queue()
	await get_tree().create_timer(0.35).timeout
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	can_drop = true

func _spawn_ball(at: Vector2, level: int):
	if not is_inside_tree() or not is_instance_valid(balls) or balls.is_queued_for_deletion():
		return null
	var ball = BallScene.instantiate()
	balls.add_child(ball)
	ball.position = at
	ball.setup(level)
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
	preview_ball.setup(current_level)
	preview_ball.lock_for_merge()
	next_preview_ball = BallScene.instantiate()
	next_preview_holder.add_child(next_preview_ball)
	next_preview_ball.scale = Vector2(0.55, 0.55)
	next_preview_ball.setup(next_level)
	next_preview_ball.lock_for_merge()

func _on_merge_requested(first, second) -> void:
	if first.merge_locked or second.merge_locked or first.merge_level >= max_level_index:
		return
	var at: Vector2 = (first.position + second.position) * 0.5
	var level: int = first.merge_level + 1
	first.lock_for_merge()
	second.lock_for_merge()
	first.queue_free()
	second.queue_free()
	var earned_points := level * 10
	score += earned_points
	score_label.text = "점수 %d" % score
	merge_scored.emit(earned_points)
	call_deferred("_spawn_ball", at, level)
	drop_grace_remaining = maxf(drop_grace_remaining, 0.5)

func _has_ball_over_danger_line() -> bool:
	for child in balls.get_children():
		if child.merge_locked:
			continue
		if child.position.y - child.get_radius() < DANGER_LINE_Y:
			return true
	return false

func _trigger_game_over() -> void:
	is_game_over = true
	can_drop = false
	guide_line.visible = false
	preview_holder.visible = false
	next_preview_holder.visible = false
	game_over.emit()

func set_input_enabled(enabled: bool) -> void:
	input_locked = not enabled
	is_aiming = false
	guide_line.visible = enabled and not is_game_over
	preview_holder.visible = enabled and not is_game_over
	next_preview_holder.visible = enabled and not is_game_over
