class_name MergeSpectrumHandler
extends TestGimmickHandler

const MergeSpectrumConfigClass = preload("res://scripts/gimmicks/configs/merge_spectrum_config.gd")
const MergeSpectrumOverlayClass = preload("res://scripts/gimmicks/visuals/merge_spectrum_overlay.gd")
const MODE_ANY_TWO := 0
const MODE_REQUIRED_PAIR := 1
const MODE_ALL := 2
const CATEGORY_LOW := 0
const CATEGORY_MID := 1
const CATEGORY_HIGH := 2
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: MergeSpectrumConfigClass
var overlay: MergeSpectrumOverlayClass
var enemy_mode := MODE_ANY_TWO
var contract_index := 0
var turns_remaining := 0
var collected: Array[bool] = [false, false, false]
var required: Array[bool] = [true, true, true]
var recent_result_stage := -1
var recent_category := -1
var result_text := ""
var result_state := RESULT_NEUTRAL


func _on_configured() -> void:
	tuning = data.tuning as MergeSpectrumConfigClass
	if tuning == null:
		tuning = MergeSpectrumConfigClass.new()
	overlay = attach_visual_layer(MergeSpectrumOverlayClass.new()) as MergeSpectrumOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_ANY_TWO, MODE_ALL) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_ALL
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
	_origin: Vector2,
	_chain_index: int,
	_source_ids: Array[int],
	_involved_cursed: bool
) -> void:
	if not active or busy or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	recent_result_stage = result_level + 1
	recent_category = _category_for_stage(recent_result_stage)
	collected[recent_category] = true
	log_event("SPECTRUM COLLECT", "stage=%d category=%s" % [recent_result_stage, _category_name(recent_category)])
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	if _contract_complete():
		_resolve_contract(true)
		return
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		_resolve_contract(false)
		return
	_update_feedback()


func _resolve_contract(succeeded: bool) -> void:
	busy = true
	merge_game.set_input_enabled(false)
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "SPECTRUM COMPLETE · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "스펙트럼 완성"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("SPECTRUM COMPLETE", "mode=%d" % enemy_mode)
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "SPECTRUM FAILED · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "스펙트럼 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("SPECTRUM FAILED", "mode=%d" % enemy_mode)
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
	collected.assign([false, false, false])
	required.assign([false, false, false])
	match enemy_mode:
		MODE_ANY_TWO:
			required.assign([true, true, true])
		MODE_REQUIRED_PAIR:
			var pair: Vector2i = _twist_pair_at(contract_index)
			required[pair.x] = true
			required[pair.y] = true
		MODE_ALL:
			required.assign([true, true, true])
	turns_remaining = _contract_turn_limit()
	recent_result_stage = -1
	recent_category = -1
	_update_feedback()


func _contract_complete() -> bool:
	if enemy_mode == MODE_ANY_TWO:
		var distinct_count := 0
		for is_collected: bool in collected:
			if is_collected:
				distinct_count += 1
		return distinct_count >= clampi(tuning.teach_required_distinct_categories, 2, 3)
	for category in 3:
		if required[category] and not collected[category]:
			return false
	return true


func _twist_pair_at(index: int) -> Vector2i:
	if tuning.twist_required_pairs.is_empty():
		return Vector2i(CATEGORY_LOW, CATEGORY_MID)
	var configured_pair: Vector2i = tuning.twist_required_pairs[index % tuning.twist_required_pairs.size()]
	var first: int = clampi(configured_pair.x, CATEGORY_LOW, CATEGORY_HIGH)
	var second: int = clampi(configured_pair.y, CATEGORY_LOW, CATEGORY_HIGH)
	if first == second:
		second = (first + 1) % 3
	return Vector2i(first, second)


func _category_for_stage(result_stage: int) -> int:
	var low_maximum: int = maxi(2, tuning.low_maximum_result_stage)
	var mid_maximum: int = maxi(low_maximum + 1, tuning.mid_maximum_result_stage)
	if result_stage <= low_maximum:
		return CATEGORY_LOW
	if result_stage <= mid_maximum:
		return CATEGORY_MID
	return CATEGORY_HIGH


func _contract_turn_limit() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.contract_turn_limits.size():
		return maxi(1, int(tuning.contract_turn_limits[enemy_index]))
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


func _category_name(category: int) -> String:
	match clampi(category, CATEGORY_LOW, CATEGORY_HIGH):
		CATEGORY_LOW: return "LOW"
		CATEGORY_MID: return "MID"
		_: return "HIGH"


func _requirement_text() -> String:
	if enemy_mode == MODE_ANY_TWO:
		return "ANY %d DISTINCT" % clampi(tuning.teach_required_distinct_categories, 2, 3)
	var names: Array[String] = []
	for category in 3:
		if required[category]:
			names.append(_category_name(category))
	return " + ".join(names)


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		collected,
		required,
		enemy_mode,
		tuning.teach_required_distinct_categories,
		tuning.low_maximum_result_stage,
		tuning.mid_maximum_result_stage,
		turns_remaining,
		recent_result_stage,
		recent_category,
		result_text,
		result_state
	)
	battle.update_gimmick_ui(
		"SPECTRUM · %s · %d턴" % [_requirement_text(), turns_remaining],
		"수집 %s · 최근 %s" % [_collected_text(), _recent_text()]
	)


func _collected_text() -> String:
	var names: Array[String] = []
	for category in 3:
		if collected[category]:
			names.append(_category_name(category))
	return "없음" if names.is_empty() else ", ".join(names)


func _recent_text() -> String:
	if recent_result_stage < 0:
		return "없음"
	return "%d단계 %s" % [recent_result_stage, _category_name(recent_category)]


func _on_cleanup() -> void:
	collected.assign([false, false, false])
	required.assign([false, false, false])
	recent_result_stage = -1
	recent_category = -1
	result_text = ""
	result_state = RESULT_NEUTRAL

