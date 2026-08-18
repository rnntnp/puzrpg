class_name MergeHeatHandler
extends TestGimmickHandler

const CHECK_VENT := 0
const CHECK_IGNITION := 1

var tuning: MergeHeatConfig
var overlay: MergeHeatOverlay
var enemy_mode := 0
var heat := 0
var check_type := CHECK_VENT
var check_index := 0
var turns_remaining := 0
var merges_this_drop := 0
var collecting_drop := false
var turn_damage_multiplier := 1.0
var result_text := ""


func _on_configured() -> void:
	tuning = data.tuning as MergeHeatConfig
	if tuning == null:
		tuning = MergeHeatConfig.new()
	heat = clampi(tuning.starting_heat, 0, tuning.maximum_heat)
	overlay = attach_visual_layer(MergeHeatOverlay.new()) as MergeHeatOverlay
	_configure_enemy()


func _on_enemy_changed() -> void:
	result_text = ""
	collecting_drop = false
	merges_this_drop = 0
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	check_index = 0
	if enemy_mode == 0:
		check_type = CHECK_VENT
	elif enemy_mode == 1:
		check_type = CHECK_IGNITION
	else:
		check_type = CHECK_IGNITION
	turns_remaining = _check_interval(enemy_index)
	turn_damage_multiplier = _damage_multiplier()
	_update_feedback()


func _on_player_ball_dropped() -> void:
	if not active or busy or not enemy.is_alive():
		return
	merges_this_drop = 0
	collecting_drop = true
	turn_damage_multiplier = _damage_multiplier()
	_update_feedback()


func _on_merge_registered(_result_level: int, _origin: Vector2, _chain_index: int, _source_ids: Array[int], _involved_cursed: bool) -> void:
	if collecting_drop:
		merges_this_drop += 1


func modify_player_damage(damage: int, _merge_result_level_index := -1, _combo_count := 1, _merge_origin := Vector2.ZERO) -> int:
	return roundi(float(damage) * turn_damage_multiplier)


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	if merges_this_drop > 0:
		heat = mini(tuning.maximum_heat, heat + merges_this_drop * tuning.heat_per_merge)
		result_text = "HEAT +%d" % (merges_this_drop * tuning.heat_per_merge)
	else:
		heat = maxi(0, heat - tuning.cooling_per_empty_drop)
		result_text = "COOLING -%d" % tuning.cooling_per_empty_drop
	collecting_drop = false
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
	turn_damage_multiplier = _damage_multiplier()
	merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _resolve_check() -> void:
	debug_special_execution_count += 1
	var is_hot: bool = heat >= tuning.hot_threshold
	var succeeded: bool = is_hot if check_type == CHECK_IGNITION else not is_hot
	if succeeded:
		result_text = "%s SUCCESS" % _check_name()
		battle.status_label.text = result_text
		battle.status_label.modulate = Color("#70ff9b")
		if tuning.success_bonus_damage > 0:
			enemy.take_damage(tuning.success_bonus_damage)
	else:
		result_text = "%s FAILED" % _check_name()
		battle.status_label.text = result_text
		battle.status_label.modulate = Color("#ff6b6b")
		if tuning.failure_attack_damage > 0:
			enemy.attack_with_damage(player, tuning.failure_attack_damage)
	log_event("HEAT CHECK", "%s heat=%d success=%s" % [_check_name(), heat, str(succeeded)])
	if enemy_mode == 2:
		check_index += 1
		check_type = CHECK_VENT if check_type == CHECK_IGNITION else CHECK_IGNITION
	turns_remaining = _check_interval(battle.current_enemy_index)


func _check_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.check_intervals.size():
		return maxi(1, tuning.check_intervals[enemy_index])
	return 4


func _heat_state() -> String:
	if heat >= tuning.hot_threshold:
		return "HOT"
	if heat >= tuning.warm_threshold:
		return "WARM"
	return "COOL"


func _damage_multiplier() -> float:
	if heat >= tuning.hot_threshold:
		return tuning.hot_damage_multiplier
	if heat >= tuning.warm_threshold:
		return tuning.warm_damage_multiplier
	return tuning.cool_damage_multiplier


func _check_name() -> String:
	return "IGNITION" if check_type == CHECK_IGNITION else "VENT"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	overlay.show_state(merge_game.get_base_board_bounds(), heat, tuning.maximum_heat, tuning.warm_threshold, tuning.hot_threshold, _damage_multiplier(), _check_name(), turns_remaining, result_text)
	battle.update_gimmick_ui("%s · %d턴" % [_check_name(), turns_remaining], "HEAT %d / %d · %s · MERGE ×%.2f" % [heat, tuning.maximum_heat, _heat_state(), _damage_multiplier()])


func _on_cleanup() -> void:
	collecting_drop = false
	merges_this_drop = 0
	result_text = ""

