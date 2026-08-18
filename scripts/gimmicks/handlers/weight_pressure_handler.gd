class_name WeightPressureHandler
extends TestGimmickHandler

const TARGET_LEFT := 0
const TARGET_RIGHT := 1
const TARGET_BOTH := 2

var tuning: WeightPressureConfig
var overlay: WeightPressureOverlay
var enemy_mode := 0
var target_index := 0
var target_plate := TARGET_LEFT
var turns_remaining := 0
var left_weight := 0.0
var right_weight := 0.0
var result_text := ""
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as WeightPressureConfig
	if tuning == null:
		tuning = WeightPressureConfig.new()
	overlay = attach_visual_layer(WeightPressureOverlay.new()) as WeightPressureOverlay
	_configure_enemy()
	_refresh_weights()


func _on_enemy_changed() -> void:
	result_text = ""
	_configure_enemy()
	_refresh_weights()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	target_index = 0
	target_plate = TARGET_LEFT
	if enemy_mode == 1:
		target_plate = TARGET_LEFT
	elif enemy_mode == 2:
		target_plate = _boss_target_at(target_index)
	turns_remaining = _interval_for_target(enemy_index, target_plate)
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_weights()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		_resolve_check()
		if not enemy.is_alive() or not player.is_alive():
			busy = false
			return
		await get_tree().create_timer(tuning.feedback_duration, true, false, true).timeout
		result_text = ""
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _physics_process_gimmick(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < 0.15:
		return
	refresh_elapsed = 0.0
	_refresh_weights()


func _refresh_weights() -> void:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var left_end: float = bounds.position.x + bounds.size.x * tuning.plate_width_ratio
	var right_start: float = bounds.end.x - bounds.size.x * tuning.plate_width_ratio
	var next_left := 0.0
	var next_right := 0.0
	for ball in valid_balls():
		var ball_weight: float = pow(maxf(0.01, ball.mass), tuning.stage_weight_exponent)
		if ball.position.x <= left_end:
			next_left += ball_weight
		elif ball.position.x >= right_start:
			next_right += ball_weight
	left_weight = next_left
	right_weight = next_right
	_update_feedback()


func _resolve_check() -> void:
	debug_special_execution_count += 1
	var succeeded: bool = _target_is_active(target_plate)
	if succeeded:
		result_text = "PLATE ACTIVE · SUCCESS"
		battle.status_label.text = "WEIGHT CHECK SUCCESS"
		battle.status_label.modulate = Color("#70ff9b")
		if tuning.success_bonus_damage > 0:
			enemy.take_damage(tuning.success_bonus_damage)
		log_event("CHECK SUCCESS", _target_name(target_plate))
	else:
		result_text = "PLATE INACTIVE · ATTACK"
		battle.status_label.text = "WEIGHT CHECK FAILED"
		battle.status_label.modulate = Color("#ff6b6b")
		if tuning.failure_attack_damage > 0:
			enemy.attack_with_damage(player, tuning.failure_attack_damage)
		log_event("CHECK FAILED", _target_name(target_plate))
	if enemy_mode == 1:
		target_plate = TARGET_RIGHT if target_plate == TARGET_LEFT else TARGET_LEFT
	elif enemy_mode == 2:
		target_index += 1
		target_plate = _boss_target_at(target_index)
	turns_remaining = _interval_for_target(battle.current_enemy_index, target_plate)
	_update_feedback()


func _target_is_active(target: int) -> bool:
	if target == TARGET_LEFT:
		return left_weight >= tuning.required_weight
	if target == TARGET_RIGHT:
		return right_weight >= tuning.required_weight
	return left_weight >= tuning.required_weight and right_weight >= tuning.required_weight


func _boss_target_at(index: int) -> int:
	var pattern: Array[int] = [TARGET_LEFT, TARGET_RIGHT, TARGET_BOTH]
	return pattern[index % pattern.size()]


func _interval_for_target(enemy_index: int, target: int) -> int:
	if target == TARGET_BOTH:
		return maxi(1, tuning.both_check_interval)
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, tuning.check_intervals[enemy_index])
	return 4


func _target_name(target: int) -> String:
	if target == TARGET_RIGHT:
		return "RIGHT"
	if target == TARGET_BOTH:
		return "BOTH"
	return "LEFT"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	overlay.show_state(bounds, tuning.plate_width_ratio, left_weight, right_weight, tuning.required_weight, target_plate, turns_remaining, result_text)
	battle.update_gimmick_ui(
		"NEXT: %s PLATE · %d턴" % [_target_name(target_plate), turns_remaining],
		"LEFT %.1f / %.1f | RIGHT %.1f / %.1f" % [left_weight, tuning.required_weight, right_weight, tuning.required_weight]
	)


func _on_cleanup() -> void:
	result_text = ""

