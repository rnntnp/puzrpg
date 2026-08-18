class_name StageCrownHandler
extends TestGimmickHandler

const StageCrownConfigClass = preload("res://scripts/gimmicks/configs/stage_crown_config.gd")
const StageCrownOverlayClass = preload("res://scripts/gimmicks/visuals/stage_crown_overlay.gd")
const MODE_UNIQUE_CROWN := 0
const MODE_TIED_CROWNS := 1
const MODE_STAIRCASE := 2
const DIRECTION_ASCENDING := 0
const DIRECTION_DESCENDING := 1
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: StageCrownConfigClass
var overlay: StageCrownOverlayClass
var enemy_mode := MODE_UNIQUE_CROWN
var contract_index := 0
var turns_remaining := 0
var crown_zone := 0
var crown_pair := Vector2i(0, 2)
var staircase_direction := DIRECTION_ASCENDING
var zone_highest_stages: Array[int] = [0, 0, 0]
var zone_ball_counts: Array[int] = [0, 0, 0]
var highest_ball_positions: Array[Vector2] = []
var result_text := ""
var result_state := RESULT_NEUTRAL
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as StageCrownConfigClass
	if tuning == null:
		tuning = StageCrownConfigClass.new()
	overlay = attach_visual_layer(StageCrownOverlayClass.new()) as StageCrownOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_UNIQUE_CROWN, MODE_STAIRCASE) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_STAIRCASE
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
	_refresh_state()
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
	_refresh_state()


func _resolve_contract(succeeded: bool) -> void:
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "CROWN COMPLETE · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "단계 왕관 완성"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("CROWN COMPLETE", _state_text())
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "CROWN FAILED · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "단계 왕관 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("CROWN FAILED", _state_text())
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
	match enemy_mode:
		MODE_UNIQUE_CROWN:
			crown_zone = _teach_zone_at(contract_index)
		MODE_TIED_CROWNS:
			crown_pair = _twist_pair_at(contract_index)
		MODE_STAIRCASE:
			staircase_direction = _boss_direction_at(contract_index)
	turns_remaining = _check_interval()
	_refresh_state()


func _refresh_state(update_feedback := true) -> void:
	var next_highest: Array[int] = [0, 0, 0]
	var next_counts: Array[int] = [0, 0, 0]
	var balls: Array[MergeBall] = valid_balls(_minimum_stage(), _maximum_stage())
	for ball: MergeBall in balls:
		var zone: int = _zone_for_x(ball.position.x)
		var displayed_stage: int = ball.merge_level + 1
		next_counts[zone] += 1
		next_highest[zone] = maxi(next_highest[zone], displayed_stage)
	zone_highest_stages.assign(next_highest)
	zone_ball_counts.assign(next_counts)
	highest_ball_positions.clear()
	for ball: MergeBall in balls:
		var zone: int = _zone_for_x(ball.position.x)
		if ball.merge_level + 1 == zone_highest_stages[zone]:
			highest_ball_positions.append(ball.position)
	if update_feedback:
		_update_feedback()


func _contract_matches() -> bool:
	if not _has_required_occupancy():
		return false
	match enemy_mode:
		MODE_UNIQUE_CROWN:
			for zone in 3:
				if zone != crown_zone and zone_highest_stages[crown_zone] <= zone_highest_stages[zone]:
					return false
			return true
		MODE_TIED_CROWNS:
			var other_zone: int = 3 - crown_pair.x - crown_pair.y
			return zone_highest_stages[crown_pair.x] == zone_highest_stages[crown_pair.y] and zone_highest_stages[crown_pair.x] > zone_highest_stages[other_zone]
		MODE_STAIRCASE:
			var minimum_step: int = maxi(1, tuning.boss_minimum_stage_step)
			if staircase_direction == DIRECTION_ASCENDING:
				return zone_highest_stages[1] - zone_highest_stages[0] >= minimum_step and zone_highest_stages[2] - zone_highest_stages[1] >= minimum_step
			return zone_highest_stages[0] - zone_highest_stages[1] >= minimum_step and zone_highest_stages[1] - zone_highest_stages[2] >= minimum_step
		_:
			return false


func _has_required_occupancy() -> bool:
	var required_count: int = maxi(1, tuning.minimum_balls_per_zone)
	for zone in 3:
		if zone_ball_counts[zone] < required_count:
			return false
	return true


func _teach_zone_at(index: int) -> int:
	if tuning.teach_crown_zone_pattern.is_empty():
		return index % 3
	return clampi(int(tuning.teach_crown_zone_pattern[index % tuning.teach_crown_zone_pattern.size()]), 0, 2)


func _twist_pair_at(index: int) -> Vector2i:
	var pair: Vector2i = Vector2i(0, 2)
	if not tuning.twist_crown_pair_pattern.is_empty():
		pair = tuning.twist_crown_pair_pattern[index % tuning.twist_crown_pair_pattern.size()]
	var first: int = clampi(pair.x, 0, 2)
	var second: int = clampi(pair.y, 0, 2)
	if first == second:
		second = (first + 1) % 3
	return Vector2i(first, second)


func _boss_direction_at(index: int) -> int:
	if tuning.boss_direction_pattern.is_empty():
		return DIRECTION_ASCENDING
	return clampi(int(tuning.boss_direction_pattern[index % tuning.boss_direction_pattern.size()]), DIRECTION_ASCENDING, DIRECTION_DESCENDING)


func _zone_for_x(x_position: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var normalized: float = clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _minimum_stage() -> int:
	return clampi(tuning.minimum_counted_stage, 1, 11)


func _maximum_stage() -> int:
	return clampi(maxi(_minimum_stage(), tuning.maximum_counted_stage), 1, 11)


func _check_interval() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, int(tuning.check_intervals[enemy_index]))
	return 6


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


func _requirement_text() -> String:
	match enemy_mode:
		MODE_UNIQUE_CROWN:
			return "%s UNIQUE TOP" % _zone_name(crown_zone)
		MODE_TIED_CROWNS:
			return "%s + %s TIED TOP" % [_zone_name(crown_pair.x), _zone_name(crown_pair.y)]
		MODE_STAIRCASE:
			return "LEFT < CENTER < RIGHT" if staircase_direction == DIRECTION_ASCENDING else "LEFT > CENTER > RIGHT"
		_:
			return "CROWN"


func _state_text() -> String:
	return "S%d | S%d | S%d" % [zone_highest_stages[0], zone_highest_stages[1], zone_highest_stages[2]]


func _zone_name(zone: int) -> String:
	match clampi(zone, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		enemy_mode,
		crown_zone,
		crown_pair,
		staircase_direction,
		zone_highest_stages,
		zone_ball_counts,
		highest_ball_positions,
		turns_remaining,
		result_text,
		result_state
	)
	battle.update_gimmick_ui("STAGE CROWN · %s · %d턴" % [_requirement_text(), turns_remaining], "대표 단계 %s" % _state_text())


func _on_cleanup() -> void:
	zone_highest_stages.assign([0, 0, 0])
	zone_ball_counts.assign([0, 0, 0])
	highest_ball_positions.clear()
	result_text = ""
	result_state = RESULT_NEUTRAL
	refresh_elapsed = 0.0
