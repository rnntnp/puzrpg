class_name BallCountContractHandler
extends TestGimmickHandler

const BallCountContractConfigClass = preload("res://scripts/gimmicks/configs/ball_count_contract_config.gd")
const BallCountContractOverlayClass = preload("res://scripts/gimmicks/visuals/ball_count_contract_overlay.gd")
const MODE_SINGLE_ZONE := 0
const MODE_DUAL_ZONE := 1
const MODE_ALL_ZONES := 2
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: BallCountContractConfigClass
var overlay: BallCountContractOverlayClass
var enemy_mode := MODE_SINGLE_ZONE
var contract_index := 0
var turns_remaining := 0
var baseline_counts: Array[int] = [0, 0, 0]
var target_counts: Array[int] = [-1, -1, -1]
var current_counts: Array[int] = [0, 0, 0]
var result_text := ""
var result_state := RESULT_NEUTRAL
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as BallCountContractConfigClass
	if tuning == null:
		tuning = BallCountContractConfigClass.new()
	overlay = attach_visual_layer(BallCountContractOverlayClass.new()) as BallCountContractOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_SINGLE_ZONE, MODE_ALL_ZONES) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_ALL_ZONES
	contract_index = 0
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0
	_begin_contract()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_counts()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		merge_game.set_input_enabled(true)
		busy = false
		_update_feedback()
		return
	_resolve_contract()
	if not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	await get_tree().create_timer(tuning.result_feedback_duration, true, false, true).timeout
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	result_text = ""
	result_state = RESULT_NEUTRAL
	battle.status_label.text = "전투 중"
	battle.status_label.modulate = Color.WHITE
	_begin_contract()
	merge_game.set_input_enabled(true)
	busy = false


func _physics_process_gimmick(delta: float) -> void:
	if busy:
		return
	refresh_elapsed += delta
	if refresh_elapsed < tuning.live_refresh_interval:
		return
	refresh_elapsed = 0.0
	_refresh_counts()


func _begin_contract() -> void:
	_refresh_counts(false)
	baseline_counts.assign(current_counts)
	target_counts.assign([-1, -1, -1])
	match enemy_mode:
		MODE_SINGLE_ZONE:
			var zone: int = _teach_zone_at(contract_index)
			target_counts[zone] = baseline_counts[zone] + maxi(1, tuning.teach_required_addition)
		MODE_DUAL_ZONE:
			var pair: Vector2i = _twist_pair_at(contract_index)
			target_counts[pair.x] = baseline_counts[pair.x] + maxi(1, tuning.twist_additions.x)
			target_counts[pair.y] = baseline_counts[pair.y] + maxi(1, tuning.twist_additions.y)
		MODE_ALL_ZONES:
			var additions: Vector3i = _boss_additions_at(contract_index)
			target_counts[0] = baseline_counts[0] + maxi(1, additions.x)
			target_counts[1] = baseline_counts[1] + maxi(1, additions.y)
			target_counts[2] = baseline_counts[2] + maxi(1, additions.z)
	contract_index += 1
	turns_remaining = _check_interval()
	_update_feedback()


func _resolve_contract() -> void:
	debug_special_execution_count += 1
	var succeeded: bool = _contract_matches()
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "COUNT MATCH · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "COUNT CONTRACT SUCCESS"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("COUNT MATCH", _counts_text())
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "COUNT MISS · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "COUNT CONTRACT FAILED"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("COUNT MISS", "current=%s target=%s" % [_counts_text(), _targets_text()])
		if attack_damage > 0:
			enemy.attack_with_damage(player, attack_damage)
	_update_feedback()


func _refresh_counts(update_feedback := true) -> void:
	var next_counts: Array[int] = [0, 0, 0]
	for ball in valid_balls():
		var zone: int = _zone_for_x(ball.position.x)
		next_counts[zone] += 1
	var changed: bool = next_counts != current_counts
	current_counts.assign(next_counts)
	if update_feedback and changed:
		_update_feedback()


func _contract_matches() -> bool:
	for zone in 3:
		if target_counts[zone] >= 0 and current_counts[zone] != target_counts[zone]:
			return false
	return true


func _teach_zone_at(index: int) -> int:
	if tuning.teach_zone_pattern.is_empty():
		return index % 3
	return clampi(int(tuning.teach_zone_pattern[index % tuning.teach_zone_pattern.size()]), 0, 2)


func _twist_pair_at(index: int) -> Vector2i:
	if tuning.twist_zone_pairs.is_empty():
		return Vector2i(index % 3, (index + 1) % 3)
	var pair: Vector2i = tuning.twist_zone_pairs[index % tuning.twist_zone_pairs.size()]
	var first: int = clampi(pair.x, 0, 2)
	var second: int = clampi(pair.y, 0, 2)
	if first == second:
		second = (first + 1) % 3
	return Vector2i(first, second)


func _boss_additions_at(index: int) -> Vector3i:
	if tuning.boss_addition_patterns.is_empty():
		return Vector3i(2, 1, 1)
	return tuning.boss_addition_patterns[index % tuning.boss_addition_patterns.size()]


func _check_interval() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, int(tuning.check_intervals[enemy_index]))
	return 4


func _success_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.success_bonus_damage.size():
		return maxi(0, int(tuning.success_bonus_damage[enemy_index]))
	return 20


func _failure_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.failure_attack_damage.size():
		return maxi(0, int(tuning.failure_attack_damage[enemy_index]))
	return 15


func _zone_for_x(x_position: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var normalized: float = clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _counts_text() -> String:
	return "%d | %d | %d" % [current_counts[0], current_counts[1], current_counts[2]]


func _targets_text() -> String:
	return "%s | %s | %s" % [_target_text(0), _target_text(1), _target_text(2)]


func _target_text(zone: int) -> String:
	return "ANY" if target_counts[zone] < 0 else str(target_counts[zone])


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		baseline_counts,
		current_counts,
		target_counts,
		turns_remaining,
		result_text,
		result_state
	)
	battle.update_gimmick_ui(
		"COUNT CONTRACT · %d턴" % turns_remaining,
		"현재 %s · 목표 %s" % [_counts_text(), _targets_text()]
	)


func _on_cleanup() -> void:
	baseline_counts.assign([0, 0, 0])
	target_counts.assign([-1, -1, -1])
	current_counts.assign([0, 0, 0])
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0

