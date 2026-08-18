class_name SeesawWeightHandler
extends TestGimmickHandler

const NO_TARGET := 2

var tuning: SeesawWeightConfig
var overlay: SeesawWeightOverlay
var enemy_mode := 0
var target_index := 0
var target_state := NO_TARGET
var turns_remaining := -1
var normal_attack_turns := 0
var left_weight := 0.0
var right_weight := 0.0
var current_state := 0
var result_text := ""
var emphasize_remaining := 0.0
var seesaw_body: AnimatableBody2D
var seesaw_size := Vector2.ZERO
var pivot := Vector2.ZERO


func _on_configured() -> void:
	tuning = data.tuning as SeesawWeightConfig
	if tuning == null:
		tuning = SeesawWeightConfig.new()
	overlay = attach_visual_layer(SeesawWeightOverlay.new()) as SeesawWeightOverlay
	_create_seesaw()
	_configure_enemy_mode()
	_refresh_weight_state(true)


func _on_enemy_changed() -> void:
	result_text = ""
	emphasize_remaining = 0.0
	_configure_enemy_mode()
	_refresh_weight_state(true)
	if is_instance_valid(seesaw_body):
		merge_game.suppress_danger_line(tuning.tilt_duration + 0.1)
		seesaw_body.rotation = _rotation_for_state(current_state)
		_update_overlay()
	_apply_ball_floor_policy()


func _configure_enemy_mode() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	target_index = 0
	normal_attack_turns = data.normal_attack_interval
	if enemy_mode == 0:
		target_state = NO_TARGET
		turns_remaining = -1
	elif enemy_mode == 1:
		target_state = 0
		turns_remaining = _check_interval(enemy_index)
	else:
		target_state = _boss_target_at(target_index)
		turns_remaining = _check_interval(enemy_index)
	_update_overlay()
	_update_ui()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_weight_state(false)
	var should_check: bool = enemy_mode != 0
	if should_check:
		turns_remaining = maxi(0, turns_remaining - 1)
		if turns_remaining <= 0:
			_resolve_check()
	else:
		_advance_normal_attack()
	if not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	await _animate_seesaw_to_state()
	if not active or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	if not result_text.is_empty():
		await get_tree().create_timer(tuning.result_feedback_duration, true, false, true).timeout
		if not active or not enemy.is_alive() or not player.is_alive():
			busy = false
			return
		result_text = ""
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	merge_game.set_input_enabled(true)
	busy = false
	_update_overlay()
	_update_ui()


func _physics_process_gimmick(delta: float) -> void:
	_apply_ball_floor_policy()
	if emphasize_remaining > 0.0:
		emphasize_remaining = maxf(0.0, emphasize_remaining - delta)
		if emphasize_remaining <= 0.0:
			_update_overlay()


func _refresh_weight_state(force: bool) -> void:
	var weights: Vector2 = _calculate_weights()
	left_weight = weights.x
	right_weight = weights.y
	var next_state: int = _state_from_weights(left_weight, right_weight)
	if force or next_state != current_state:
		if not force:
			log_event("WEIGHT STATE CHANGED", "%s -> %s" % [_state_name(current_state), _state_name(next_state)])
		current_state = next_state
		emphasize_remaining = 0.55
	_update_overlay()
	_update_ui()


func _calculate_weights() -> Vector2:
	var totals: Vector2 = Vector2.ZERO
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var center_x: float = bounds.get_center().x
	var neutral_half_width: float = bounds.size.x * tuning.center_neutral_width_ratio * 0.5
	for ball in valid_balls():
		if absf(ball.position.x - center_x) <= neutral_half_width:
			continue
		var weight: float = pow(maxf(0.01, ball.mass), tuning.stage_weight_exponent)
		if ball.position.x < center_x:
			totals.x += weight
		else:
			totals.y += weight
	return totals


func _state_from_weights(left_total: float, right_total: float) -> int:
	var total: float = left_total + right_total
	if total <= 0.001:
		return 0
	if absf(left_total - right_total) <= total * tuning.balance_tolerance_ratio:
		return 0
	return -1 if left_total > right_total else 1


func _resolve_check() -> void:
	debug_special_execution_count += 1
	var matched: bool = current_state == target_state
	if matched:
		result_text = "WEIGHT MATCH · BREAK +%d" % tuning.success_bonus_damage
		battle.status_label.text = "WEIGHT CHECK SUCCESS"
		battle.status_label.modulate = Color("#70ff9b")
		if tuning.success_bonus_damage > 0:
			enemy.take_damage(tuning.success_bonus_damage)
		log_event("CHECK SUCCESS", _state_name(current_state))
	else:
		result_text = "WEIGHT MISS · ATTACK %d" % tuning.failure_attack_damage
		battle.status_label.text = "WEIGHT CHECK FAILED"
		battle.status_label.modulate = Color("#ff6b6b")
		if tuning.failure_attack_damage > 0:
			enemy.attack_with_damage(player, tuning.failure_attack_damage)
		log_event("CHECK FAILED", "target=%s current=%s" % [_state_name(target_state), _state_name(current_state)])
	if enemy_mode == 2:
		target_index += 1
		target_state = _boss_target_at(target_index)
	turns_remaining = _check_interval(battle.current_enemy_index)


func _advance_normal_attack() -> void:
	normal_attack_turns = maxi(0, normal_attack_turns - 1)
	if normal_attack_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		normal_attack_turns = data.normal_attack_interval


func _animate_seesaw_to_state() -> void:
	if not is_instance_valid(seesaw_body):
		return
	var target_rotation: float = _rotation_for_state(current_state)
	if is_equal_approx(seesaw_body.rotation, target_rotation):
		return
	merge_game.suppress_danger_line(tuning.tilt_duration + 0.1)
	var tween: Tween = create_gimmick_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(angle: float) -> void:
		if is_instance_valid(seesaw_body):
			seesaw_body.rotation = angle
			_update_overlay()
	, seesaw_body.rotation, target_rotation, tuning.tilt_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _rotation_for_state(state: int) -> float:
	if state < 0:
		return deg_to_rad(-tuning.heavy_tilt_degrees)
	if state > 0:
		return deg_to_rad(tuning.heavy_tilt_degrees)
	return 0.0


func _create_seesaw() -> void:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	seesaw_size = Vector2(bounds.size.x * tuning.seesaw_width_ratio, tuning.seesaw_thickness)
	pivot = Vector2(bounds.get_center().x, bounds.end.y - seesaw_size.y * 0.5)
	seesaw_body = AnimatableBody2D.new()
	seesaw_body.name = "WeightSeesaw"
	seesaw_body.sync_to_physics = true
	seesaw_body.collision_layer = 1
	seesaw_body.collision_mask = 1
	seesaw_body.position = pivot
	seesaw_body.add_to_group(&"drop_landing_surface")
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = seesaw_size
	collision.shape = shape
	seesaw_body.add_child(collision)
	merge_game.gimmick_objects.add_child(seesaw_body)
	merge_game.set_base_floor_collision_enabled(false)
	_apply_ball_floor_policy()


func _apply_ball_floor_policy() -> void:
	if not is_instance_valid(merge_game):
		return
	merge_game.set_ball_vertical_floor_bounds_enabled(false)


func _check_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, tuning.check_intervals[enemy_index])
	return 4


func _boss_target_at(index: int) -> int:
	if tuning.boss_target_pattern.is_empty():
		return 0
	return clampi(tuning.boss_target_pattern[index % tuning.boss_target_pattern.size()], -1, 1)


func _update_overlay() -> void:
	if not is_instance_valid(overlay):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		pivot,
		seesaw_size,
		seesaw_body.rotation if is_instance_valid(seesaw_body) else 0.0,
		left_weight,
		right_weight,
		current_state,
		target_state,
		turns_remaining,
		result_text,
		emphasize_remaining > 0.0
	)


func _update_ui() -> void:
	if not is_instance_valid(battle):
		return
	var primary: String = "STATE: %s" % _state_name(current_state)
	if target_state != NO_TARGET:
		primary = "TARGET: %s · %d턴" % [_state_name(target_state), turns_remaining]
	battle.update_gimmick_ui(primary, "LEFT %.1f | RIGHT %.1f" % [left_weight, right_weight])


func _state_name(state: int) -> String:
	if state < 0:
		return "LEFT HEAVY"
	if state > 0:
		return "RIGHT HEAVY"
	return "BALANCE"


func _on_cleanup() -> void:
	if is_instance_valid(seesaw_body):
		if seesaw_body.get_parent() != null:
			seesaw_body.get_parent().remove_child(seesaw_body)
		seesaw_body.queue_free()
	seesaw_body = null
	if is_instance_valid(merge_game):
		merge_game.set_base_floor_collision_enabled(true)
		merge_game.set_ball_vertical_floor_bounds_enabled(true)
	result_text = ""
