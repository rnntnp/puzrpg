class_name MergeLedgerHandler
extends TestGimmickHandler

const MergeLedgerConfigClass = preload("res://scripts/gimmicks/configs/merge_ledger_config.gd")
const MergeLedgerOverlayClass = preload("res://scripts/gimmicks/visuals/merge_ledger_overlay.gd")
const MODE_GLOBAL := 0
const MODE_ACTIVE_SIDE := 1
const MODE_DUAL_SIDE := 2
const SIDE_LEFT := 0
const SIDE_RIGHT := 1
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: MergeLedgerConfigClass
var overlay: MergeLedgerOverlayClass
var enemy_mode := MODE_GLOBAL
var contract_index := 0
var turns_remaining := 0
var global_total := 0
var left_total := 0
var right_total := 0
var global_target := -1
var left_target := -1
var right_target := -1
var active_side := SIDE_LEFT
var recent_result_stage := -1
var recent_side := -1
var recent_counted := false
var result_text := ""
var result_state := RESULT_NEUTRAL


func _on_configured() -> void:
	tuning = data.tuning as MergeLedgerConfigClass
	if tuning == null:
		tuning = MergeLedgerConfigClass.new()
	overlay = attach_visual_layer(MergeLedgerOverlayClass.new()) as MergeLedgerOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_GLOBAL, MODE_DUAL_SIDE) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_DUAL_SIDE
	contract_index = 0
	result_text = ""
	result_state = RESULT_NEUTRAL
	_begin_contract()


func _on_player_ball_dropped() -> void:
	if not active or busy:
		return
	result_text = ""
	result_state = RESULT_NEUTRAL
	if is_instance_valid(battle):
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	_update_feedback()


func _on_merge_registered(
	result_level: int,
	origin: Vector2,
	_chain_index: int,
	_source_ids: Array[int],
	_involved_cursed: bool
) -> void:
	if not active or busy or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	recent_result_stage = result_level + 1
	recent_side = _side_for_x(origin.x)
	recent_counted = false
	match enemy_mode:
		MODE_GLOBAL:
			global_total += recent_result_stage
			recent_counted = true
		MODE_ACTIVE_SIDE:
			if recent_side == active_side:
				_add_to_side(recent_side, recent_result_stage)
				recent_counted = true
		MODE_DUAL_SIDE:
			_add_to_side(recent_side, recent_result_stage)
			recent_counted = true
	log_event("LEDGER ENTRY", "stage=%d side=%s counted=%s" % [recent_result_stage, _side_name(recent_side), str(recent_counted)])
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	if _targets_exact():
		_resolve_contract(true, false)
		return
	if _has_overpayment():
		_resolve_contract(false, true)
		return
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		_resolve_contract(false, false)
		return
	_update_feedback()


func _resolve_contract(succeeded: bool, overpaid: bool) -> void:
	busy = true
	merge_game.set_input_enabled(false)
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "LEDGER SETTLED · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "정산 완료"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("LEDGER SETTLED", _totals_text())
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		var reason: String = "OVERPAID" if overpaid else "UNPAID"
		result_text = "%s · DAMAGE %d" % [reason, attack_damage]
		result_state = RESULT_FAILURE
		battle.status_label.text = "과납 실패" if overpaid else "미납 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("LEDGER FAILED", "%s %s" % [reason, _totals_text()])
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
	global_total = 0
	left_total = 0
	right_total = 0
	global_target = -1
	left_target = -1
	right_target = -1
	match enemy_mode:
		MODE_GLOBAL:
			global_target = maxi(2, _pattern_int(tuning.teach_target_pattern, contract_index, 6))
		MODE_ACTIVE_SIDE:
			active_side = clampi(_pattern_int(tuning.twist_side_pattern, contract_index, SIDE_LEFT), SIDE_LEFT, SIDE_RIGHT)
			var side_target: int = maxi(2, _pattern_int(tuning.twist_target_pattern, contract_index, 6))
			if active_side == SIDE_LEFT:
				left_target = side_target
			else:
				right_target = side_target
		MODE_DUAL_SIDE:
			var targets: Vector2i = _boss_targets_at(contract_index)
			left_target = maxi(2, targets.x)
			right_target = maxi(2, targets.y)
	turns_remaining = _contract_turn_limit()
	recent_result_stage = -1
	recent_side = -1
	recent_counted = false
	_update_feedback()


func _targets_exact() -> bool:
	match enemy_mode:
		MODE_GLOBAL:
			return global_total == global_target
		MODE_ACTIVE_SIDE:
			return left_total == left_target if active_side == SIDE_LEFT else right_total == right_target
		MODE_DUAL_SIDE:
			return left_total == left_target and right_total == right_target
		_:
			return false


func _has_overpayment() -> bool:
	match enemy_mode:
		MODE_GLOBAL:
			return global_total > global_target
		MODE_ACTIVE_SIDE:
			return left_total > left_target if active_side == SIDE_LEFT else right_total > right_target
		MODE_DUAL_SIDE:
			return left_total > left_target or right_total > right_target
		_:
			return false


func _add_to_side(side: int, amount: int) -> void:
	if side == SIDE_LEFT:
		left_total += amount
	else:
		right_total += amount


func _side_for_x(x_position: float) -> int:
	return SIDE_LEFT if x_position < merge_game.get_base_board_bounds().get_center().x else SIDE_RIGHT


func _pattern_int(pattern: Array[int], index: int, fallback: int) -> int:
	if pattern.is_empty():
		return fallback
	return int(pattern[index % pattern.size()])


func _boss_targets_at(index: int) -> Vector2i:
	if tuning.boss_target_pattern.is_empty():
		return Vector2i(5, 7)
	return tuning.boss_target_pattern[index % tuning.boss_target_pattern.size()]


func _contract_turn_limit() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.contract_turn_limits.size():
		return maxi(1, int(tuning.contract_turn_limits[enemy_index]))
	return 6


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


func _side_name(side: int) -> String:
	return "LEFT" if side == SIDE_LEFT else "RIGHT"


func _mode_name() -> String:
	match enemy_mode:
		MODE_GLOBAL: return "GLOBAL"
		MODE_ACTIVE_SIDE: return _side_name(active_side)
		_: return "DUAL"


func _totals_text() -> String:
	if enemy_mode == MODE_GLOBAL:
		return "%d/%d" % [global_total, global_target]
	if enemy_mode == MODE_ACTIVE_SIDE:
		return "%s %d/%d" % [_side_name(active_side), left_total if active_side == SIDE_LEFT else right_total, left_target if active_side == SIDE_LEFT else right_target]
	return "LEFT %d/%d RIGHT %d/%d" % [left_total, left_target, right_total, right_target]


func _recent_text() -> String:
	if recent_result_stage < 0:
		return "최근 합성 없음"
	return "%s %d단계 · %s" % [_side_name(recent_side), recent_result_stage, "COUNTED" if recent_counted else "IGNORED"]


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		enemy_mode,
		active_side,
		global_total,
		left_total,
		right_total,
		global_target,
		left_target,
		right_target,
		turns_remaining,
		recent_result_stage,
		recent_side,
		recent_counted,
		result_text,
		result_state
	)
	battle.update_gimmick_ui(
		"MERGE LEDGER · %s · %d턴" % [_mode_name(), turns_remaining],
		"%s · %s" % [_totals_text(), _recent_text()]
	)


func _on_cleanup() -> void:
	global_total = 0
	left_total = 0
	right_total = 0
	global_target = -1
	left_target = -1
	right_target = -1
	recent_result_stage = -1
	recent_side = -1
	recent_counted = false
	result_text = ""
	result_state = RESULT_NEUTRAL
