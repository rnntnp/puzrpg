class_name StageCensusHandler
extends TestGimmickHandler

const StageCensusConfigClass = preload("res://scripts/gimmicks/configs/stage_census_config.gd")
const StageCensusOverlayClass = preload("res://scripts/gimmicks/visuals/stage_census_overlay.gd")
const MODE_SINGLE_STAGE := 0
const MODE_DUAL_STAGE := 1
const MODE_STAGE_BANDS := 2
const SIDE_LEFT := 0
const SIDE_RIGHT := 1
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: StageCensusConfigClass
var overlay: StageCensusOverlayClass
var enemy_mode := MODE_SINGLE_STAGE
var contract_index := 0
var turns_remaining := 0
var target_ranges: Array[Vector2i] = []
var target_deltas: Array[int] = []
var left_counts: Array[int] = []
var right_counts: Array[int] = []
var left_target_positions: Array[Vector2] = []
var right_target_positions: Array[Vector2] = []
var result_text := ""
var result_state := RESULT_NEUTRAL
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as StageCensusConfigClass
	if tuning == null:
		tuning = StageCensusConfigClass.new()
	overlay = attach_visual_layer(StageCensusOverlayClass.new()) as StageCensusOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_SINGLE_STAGE, MODE_STAGE_BANDS) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_STAGE_BANDS
	contract_index = 0
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0
	_begin_contract()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	var checked_enemy: Fighter = enemy
	busy = true
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or enemy != checked_enemy or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_counts()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		merge_game.set_input_enabled(true)
		busy = false
		_update_feedback()
		return
	_resolve_contract(_contract_matches())


func _physics_process_gimmick(delta: float) -> void:
	if busy:
		return
	refresh_elapsed += delta
	if refresh_elapsed < tuning.live_refresh_interval:
		return
	refresh_elapsed = 0.0
	_refresh_counts()


func _resolve_contract(succeeded: bool) -> void:
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "CENSUS MATCH · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "단계 인구조사 성공"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("CENSUS MATCH", _counts_text())
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "CENSUS MISS · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "단계 인구조사 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("CENSUS MISS", _counts_text())
		if attack_damage > 0:
			enemy.attack_with_damage(player, attack_damage)
	_update_feedback()
	if not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	await get_tree().create_timer(tuning.result_feedback_duration, true, false, true).timeout
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	contract_index += 1
	result_text = ""
	result_state = RESULT_NEUTRAL
	battle.status_label.text = "전투 중"
	battle.status_label.modulate = Color.WHITE
	_begin_contract()
	merge_game.set_input_enabled(true)
	busy = false


func _begin_contract() -> void:
	target_ranges.clear()
	target_deltas.clear()
	match enemy_mode:
		MODE_SINGLE_STAGE:
			var target_stage: int = _teach_stage_at(contract_index)
			target_ranges.append(Vector2i(target_stage, target_stage))
			target_deltas.append(_teach_delta_at(contract_index))
		MODE_DUAL_STAGE:
			var stages: Vector2i = _twist_stages_at(contract_index)
			var deltas: Vector2i = _twist_deltas_at(contract_index)
			target_ranges.append(Vector2i(stages.x, stages.x))
			target_ranges.append(Vector2i(stages.y, stages.y))
			target_deltas.append(deltas.x)
			target_deltas.append(deltas.y)
		MODE_STAGE_BANDS:
			var boss_deltas: Vector3i = _boss_deltas_at(contract_index)
			target_ranges.append(_normalized_range(tuning.boss_low_stage_range))
			target_ranges.append(_normalized_range(tuning.boss_mid_stage_range))
			target_ranges.append(_normalized_range(tuning.boss_high_stage_range))
			target_deltas.append(boss_deltas.x)
			target_deltas.append(boss_deltas.y)
			target_deltas.append(boss_deltas.z)
	turns_remaining = _check_interval()
	_refresh_counts(false)
	_update_feedback()


func _refresh_counts(update_feedback := true) -> void:
	var next_left: Array[int] = []
	var next_right: Array[int] = []
	next_left.resize(target_ranges.size())
	next_right.resize(target_ranges.size())
	next_left.fill(0)
	next_right.fill(0)
	left_target_positions.clear()
	right_target_positions.clear()
	var balls: Array[MergeBall] = valid_balls()
	for ball: MergeBall in balls:
		var displayed_stage: int = ball.merge_level + 1
		var side: int = _side_for_x(ball.position.x)
		var matches_any: bool = false
		for target_index in target_ranges.size():
			var stage_range: Vector2i = target_ranges[target_index]
			if displayed_stage < stage_range.x or displayed_stage > stage_range.y:
				continue
			matches_any = true
			if side == SIDE_LEFT:
				next_left[target_index] += 1
			else:
				next_right[target_index] += 1
		if matches_any:
			if side == SIDE_LEFT:
				left_target_positions.append(ball.position)
			else:
				right_target_positions.append(ball.position)
	left_counts.assign(next_left)
	right_counts.assign(next_right)
	if update_feedback:
		_update_feedback()


func _contract_matches() -> bool:
	var minimum_total: int = _minimum_target_total()
	for target_index in target_ranges.size():
		if left_counts[target_index] + right_counts[target_index] < minimum_total:
			return false
		if left_counts[target_index] - right_counts[target_index] != target_deltas[target_index]:
			return false
	return not target_ranges.is_empty()


func _teach_stage_at(index: int) -> int:
	if tuning.teach_stage_pattern.is_empty():
		return 1 + index % 5
	return clampi(int(tuning.teach_stage_pattern[index % tuning.teach_stage_pattern.size()]), 1, 11)


func _teach_delta_at(index: int) -> int:
	if tuning.teach_delta_pattern.is_empty():
		return 1 if index % 2 == 0 else -1
	return int(tuning.teach_delta_pattern[index % tuning.teach_delta_pattern.size()])


func _twist_stages_at(index: int) -> Vector2i:
	var pair: Vector2i = Vector2i(1, 2)
	if not tuning.twist_stage_pair_pattern.is_empty():
		pair = tuning.twist_stage_pair_pattern[index % tuning.twist_stage_pair_pattern.size()]
	var first: int = clampi(pair.x, 1, 11)
	var second: int = clampi(pair.y, 1, 11)
	if first == second:
		second = clampi(first + 1, 1, 11)
		if second == first:
			second = first - 1
	return Vector2i(first, second)


func _twist_deltas_at(index: int) -> Vector2i:
	if tuning.twist_delta_pattern.is_empty():
		return Vector2i(1, -1)
	return tuning.twist_delta_pattern[index % tuning.twist_delta_pattern.size()]


func _boss_deltas_at(index: int) -> Vector3i:
	if tuning.boss_delta_pattern.is_empty():
		return Vector3i(1, 0, -1)
	return tuning.boss_delta_pattern[index % tuning.boss_delta_pattern.size()]


func _normalized_range(stage_range: Vector2i) -> Vector2i:
	var first: int = clampi(mini(stage_range.x, stage_range.y), 1, 11)
	var second: int = clampi(maxi(stage_range.x, stage_range.y), first, 11)
	return Vector2i(first, second)


func _side_for_x(x_position: float) -> int:
	return SIDE_LEFT if x_position < merge_game.get_base_board_bounds().get_center().x else SIDE_RIGHT


func _check_interval() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, int(tuning.check_intervals[enemy_index]))
	return 6


func _minimum_target_total() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.minimum_target_totals.size():
		return maxi(1, int(tuning.minimum_target_totals[enemy_index]))
	return 2


func _success_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.success_bonus_damage.size():
		return maxi(0, int(tuning.success_bonus_damage[enemy_index]))
	return 24


func _failure_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.failure_attack_damage.size():
		return maxi(0, int(tuning.failure_attack_damage[enemy_index]))
	return 12


func _stage_label(stage_range: Vector2i) -> String:
	return "S%d" % stage_range.x if stage_range.x == stage_range.y else "S%d-%d" % [stage_range.x, stage_range.y]


func _counts_text() -> String:
	var entries: Array[String] = []
	for target_index in target_ranges.size():
		entries.append("%s L%d R%d Δ%d/%d" % [_stage_label(target_ranges[target_index]), left_counts[target_index], right_counts[target_index], left_counts[target_index] - right_counts[target_index], target_deltas[target_index]])
	return " · ".join(entries)


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		target_ranges,
		target_deltas,
		left_counts,
		right_counts,
		left_target_positions,
		right_target_positions,
		_minimum_target_total(),
		turns_remaining,
		result_text,
		result_state
	)
	battle.update_gimmick_ui("STAGE CENSUS · %d항목 · %d턴" % [target_ranges.size(), turns_remaining], _counts_text())


func _on_cleanup() -> void:
	target_ranges.clear()
	target_deltas.clear()
	left_counts.clear()
	right_counts.clear()
	left_target_positions.clear()
	right_target_positions.clear()
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0
