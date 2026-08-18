class_name PairReserveHandler
extends TestGimmickHandler

const PairReserveConfigClass = preload("res://scripts/gimmicks/configs/pair_reserve_config.gd")
const PairReserveOverlayClass = preload("res://scripts/gimmicks/visuals/pair_reserve_overlay.gd")
const MODE_GLOBAL_ONE := 0
const MODE_GLOBAL_MULTI := 1
const MODE_SPLIT := 2
const SIDE_LEFT := 0
const SIDE_RIGHT := 1
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: PairReserveConfigClass
var overlay: PairReserveOverlayClass
var enemy_mode := MODE_GLOBAL_ONE
var turns_remaining := 0
var global_pair_stages: Array[int] = []
var left_pair_stages: Array[int] = []
var right_pair_stages: Array[int] = []
var excluded_global_stages: Array[int] = []
var excluded_left_stages: Array[int] = []
var excluded_right_stages: Array[int] = []
var qualified_ball_positions: Array[Vector2] = []
var excluded_ball_positions: Array[Vector2] = []
var selected_success_global: Array[int] = []
var selected_success_left := -1
var selected_success_right := -1
var result_text := ""
var result_state := RESULT_NEUTRAL
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as PairReserveConfigClass
	if tuning == null:
		tuning = PairReserveConfigClass.new()
	overlay = attach_visual_layer(PairReserveOverlayClass.new()) as PairReserveOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_GLOBAL_ONE, MODE_SPLIT) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_SPLIT
	excluded_global_stages.clear()
	excluded_left_stages.clear()
	excluded_right_stages.clear()
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
	_refresh_reserves()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		merge_game.set_input_enabled(true)
		busy = false
		_update_feedback()
		return
	var succeeded: bool = _select_success_reserves()
	_resolve_check(succeeded)


func _physics_process_gimmick(delta: float) -> void:
	if busy:
		return
	refresh_elapsed += delta
	if refresh_elapsed < tuning.live_refresh_interval:
		return
	refresh_elapsed = 0.0
	_refresh_reserves()


func _resolve_check(succeeded: bool) -> void:
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "RESERVE READY · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "예비군 완성"
		battle.status_label.modulate = Color("#70ff9b")
		_set_next_exclusions()
		log_event("RESERVE READY", _pairs_text())
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "RESERVE FAILED · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "예비군 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		_clear_exclusions()
		log_event("RESERVE FAILED", _pairs_text())
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
	result_text = ""
	result_state = RESULT_NEUTRAL
	battle.status_label.text = "전투 중"
	battle.status_label.modulate = Color.WHITE
	_begin_contract()
	merge_game.set_input_enabled(true)
	busy = false


func _begin_contract() -> void:
	turns_remaining = _check_interval()
	selected_success_global.clear()
	selected_success_left = -1
	selected_success_right = -1
	_refresh_reserves()


func _refresh_reserves() -> void:
	var global_counts: Dictionary = {}
	var left_counts: Dictionary = {}
	var right_counts: Dictionary = {}
	var balls: Array[MergeBall] = valid_balls(_minimum_stage(), _maximum_stage())
	for ball: MergeBall in balls:
		var stage: int = ball.merge_level + 1
		global_counts[stage] = int(global_counts.get(stage, 0)) + 1
		if _side_for_x(ball.position.x) == SIDE_LEFT:
			left_counts[stage] = int(left_counts.get(stage, 0)) + 1
		else:
			right_counts[stage] = int(right_counts.get(stage, 0)) + 1
	global_pair_stages.assign(_pair_stages(global_counts))
	left_pair_stages.assign(_pair_stages(left_counts))
	right_pair_stages.assign(_pair_stages(right_counts))
	qualified_ball_positions.clear()
	excluded_ball_positions.clear()
	for ball: MergeBall in balls:
		var stage: int = ball.merge_level + 1
		var is_pair: bool
		var is_excluded: bool
		if enemy_mode == MODE_SPLIT:
			var side: int = _side_for_x(ball.position.x)
			is_pair = stage in (left_pair_stages if side == SIDE_LEFT else right_pair_stages)
			is_excluded = stage in (excluded_left_stages if side == SIDE_LEFT else excluded_right_stages)
		else:
			is_pair = stage in global_pair_stages
			is_excluded = stage in excluded_global_stages
		if is_pair and is_excluded:
			excluded_ball_positions.append(ball.position)
		elif is_pair:
			qualified_ball_positions.append(ball.position)
	_update_feedback()


func _pair_stages(counts: Dictionary) -> Array[int]:
	var stages: Array[int] = []
	for stage_key: Variant in counts.keys():
		var stage: int = int(stage_key)
		if int(counts[stage_key]) >= 2:
			stages.append(stage)
	stages.sort()
	return stages


func _select_success_reserves() -> bool:
	selected_success_global.clear()
	selected_success_left = -1
	selected_success_right = -1
	if enemy_mode in [MODE_GLOBAL_ONE, MODE_GLOBAL_MULTI]:
		var available: Array[int] = []
		for stage: int in global_pair_stages:
			if stage not in excluded_global_stages:
				available.append(stage)
		var required_count: int = _required_global_pair_count()
		if available.size() < required_count:
			return false
		for index in required_count:
			selected_success_global.append(available[index])
		return true
	for left_stage: int in left_pair_stages:
		if left_stage in excluded_left_stages:
			continue
		for right_stage: int in right_pair_stages:
			if right_stage in excluded_right_stages:
				continue
			if tuning.boss_requires_different_side_stages and left_stage == right_stage:
				continue
			selected_success_left = left_stage
			selected_success_right = right_stage
			return true
	return false


func _set_next_exclusions() -> void:
	_clear_exclusions()
	if not tuning.exclude_previous_success_stages:
		return
	if enemy_mode in [MODE_GLOBAL_ONE, MODE_GLOBAL_MULTI]:
		excluded_global_stages.assign(selected_success_global)
	else:
		if selected_success_left >= 0:
			excluded_left_stages.append(selected_success_left)
		if selected_success_right >= 0:
			excluded_right_stages.append(selected_success_right)


func _clear_exclusions() -> void:
	excluded_global_stages.clear()
	excluded_left_stages.clear()
	excluded_right_stages.clear()


func _side_for_x(x_position: float) -> int:
	return SIDE_LEFT if x_position < merge_game.get_base_board_bounds().get_center().x else SIDE_RIGHT


func _minimum_stage() -> int:
	return clampi(tuning.minimum_reserve_stage, 1, 11)


func _maximum_stage() -> int:
	return clampi(maxi(_minimum_stage(), tuning.maximum_reserve_stage), 1, 11)


func _required_global_pair_count() -> int:
	if enemy_mode == MODE_GLOBAL_ONE:
		return clampi(tuning.teach_required_pair_stages, 1, 3)
	return clampi(tuning.twist_required_pair_stages, 2, 5)


func _check_interval() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, int(tuning.check_intervals[enemy_index]))
	return 5


func _success_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.success_bonus_damage.size():
		return maxi(0, int(tuning.success_bonus_damage[enemy_index]))
	return 20


func _failure_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.failure_attack_damage.size():
		return maxi(0, int(tuning.failure_attack_damage[enemy_index]))
	return 12


func _pairs_text() -> String:
	if enemy_mode == MODE_SPLIT:
		return "LEFT %s · RIGHT %s" % [_stage_list(left_pair_stages), _stage_list(right_pair_stages)]
	return _stage_list(global_pair_stages)


func _stage_list(stages: Array[int]) -> String:
	if stages.is_empty():
		return "없음"
	var entries: Array[String] = []
	for stage: int in stages:
		entries.append("S%d" % stage)
	return ", ".join(entries)


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		enemy_mode,
		global_pair_stages,
		left_pair_stages,
		right_pair_stages,
		excluded_global_stages,
		excluded_left_stages,
		excluded_right_stages,
		qualified_ball_positions,
		excluded_ball_positions,
		_required_global_pair_count(),
		turns_remaining,
		result_text,
		result_state
	)
	var primary: String
	if enemy_mode == MODE_SPLIT:
		primary = "PAIR RESERVE · LEFT + RIGHT · %d턴" % turns_remaining
	else:
		primary = "PAIR RESERVE · %d종 필요 · %d턴" % [_required_global_pair_count(), turns_remaining]
	battle.update_gimmick_ui(primary, "현재 %s" % _pairs_text())


func _on_cleanup() -> void:
	global_pair_stages.clear()
	left_pair_stages.clear()
	right_pair_stages.clear()
	_clear_exclusions()
	qualified_ball_positions.clear()
	excluded_ball_positions.clear()
	selected_success_global.clear()
	selected_success_left = -1
	selected_success_right = -1
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0
