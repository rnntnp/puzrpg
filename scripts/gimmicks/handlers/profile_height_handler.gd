class_name ProfileHeightHandler
extends TestGimmickHandler

var tuning: ProfileHeightConfig
var overlay: ProfileHeightOverlay
var enemy_mode := 0
var pattern_index := 0
var turns_remaining := 0
var profile_line_y := 0.0
var current_states: Array[int] = [0, 0, 0]
var current_target := Vector3i(-1, -1, -1)
var changed_sections: Array[int] = []
var result_text := ""
var change_feedback_remaining := 0.0


func _on_configured() -> void:
	tuning = data.tuning as ProfileHeightConfig
	if tuning == null:
		tuning = ProfileHeightConfig.new()
	overlay = attach_visual_layer(ProfileHeightOverlay.new()) as ProfileHeightOverlay
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var safe_height: float = bounds.end.y - merge_game.danger_line_y
	profile_line_y = bounds.end.y - safe_height * tuning.profile_line_safe_height_ratio
	_configure_enemy_profile()
	_refresh_states(true)


func _on_enemy_changed() -> void:
	result_text = ""
	changed_sections.clear()
	change_feedback_remaining = 0.0
	_configure_enemy_profile()
	_refresh_states(true)


func _configure_enemy_profile() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	pattern_index = 0
	turns_remaining = _evaluation_interval(enemy_index)
	current_target = _profile_at(pattern_index)
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
	_refresh_states(false)
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		merge_game.set_input_enabled(true)
		busy = false
		_update_overlay()
		_update_ui()
		return
	var matched: bool = _profile_matches()
	debug_special_execution_count += 1
	if matched:
		result_text = "PROFILE MATCH · BREAK +%d" % tuning.profile_break_damage
		battle.status_label.text = "PROFILE MATCH"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("PROFILE MATCH", _profile_text(current_target))
		if tuning.profile_break_damage > 0:
			enemy.take_damage(tuning.profile_break_damage)
	else:
		result_text = "PROFILE MISS · ATTACK %d" % tuning.profile_miss_damage
		battle.status_label.text = "PROFILE MISS"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("PROFILE MISS", "target=%s current=%s" % [_profile_text(current_target), _state_text()])
		if tuning.profile_miss_damage > 0:
			enemy.attack_with_damage(player, tuning.profile_miss_damage)
	pattern_index += 1
	current_target = _profile_at(pattern_index)
	turns_remaining = _evaluation_interval(battle.current_enemy_index)
	_update_overlay()
	_update_ui()
	if not enemy.is_alive() or not player.is_alive():
		busy = false
		return
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
	if busy:
		return
	_refresh_states(false)
	if change_feedback_remaining > 0.0:
		change_feedback_remaining = maxf(0.0, change_feedback_remaining - delta)
		if change_feedback_remaining <= 0.0 and not changed_sections.is_empty():
			changed_sections.clear()
			_update_overlay()


func _refresh_states(force: bool) -> void:
	var next_states: Array[int] = _read_states()
	var changes: Array[int] = []
	for index in 3:
		if next_states[index] != current_states[index]:
			changes.append(index)
			log_event("HEIGHT CHANGED", "%s %s->%s" % [_section_name(index), _state_name(current_states[index]), _state_name(next_states[index])])
	current_states.assign(next_states)
	if not changes.is_empty():
		changed_sections.assign(changes)
		change_feedback_remaining = tuning.state_change_feedback_duration
	if force or not changes.is_empty():
		_update_overlay()
		_update_ui()


func _read_states() -> Array[int]:
	var states: Array[int] = [0, 0, 0]
	for ball in valid_balls():
		var section: int = _section_for_x(ball.position.x)
		var top_y: float = ball.position.y - ball.get_radius()
		if top_y <= profile_line_y:
			states[section] = 1
	return states


func _profile_matches() -> bool:
	for index in 3:
		var required: int = current_target[index]
		if required >= 0 and current_states[index] != required:
			return false
	return true


func _profile_at(index: int) -> Vector3i:
	var patterns: Array[Vector3i] = _active_patterns()
	if patterns.is_empty():
		return Vector3i(-1, -1, -1)
	return patterns[index % patterns.size()]


func _active_patterns() -> Array[Vector3i]:
	match enemy_mode:
		0: return tuning.single_section_profiles
		1: return tuning.dual_section_profiles
		_: return tuning.boss_profiles


func _evaluation_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.evaluation_intervals.size():
		return maxi(1, tuning.evaluation_intervals[enemy_index])
	return 4


func _section_for_x(x_position: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var normalized: float = clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _update_overlay() -> void:
	if not is_instance_valid(overlay):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		profile_line_y,
		current_states,
		current_target,
		turns_remaining,
		result_text,
		changed_sections
	)


func _update_ui() -> void:
	if not is_instance_valid(battle):
		return
	battle.update_gimmick_ui(
		"PROFILE: %s · %d턴" % [_profile_text(current_target), turns_remaining],
		"현재: %s" % _state_text()
	)


func _profile_text(profile: Vector3i) -> String:
	return "%s | %s | %s" % [_state_name(profile.x), _state_name(profile.y), _state_name(profile.z)]


func _state_text() -> String:
	return "%s | %s | %s" % [_state_name(current_states[0]), _state_name(current_states[1]), _state_name(current_states[2])]


func _state_name(state: int) -> String:
	if state < 0:
		return "ANY"
	return "HIGH" if state == 1 else "LOW"


func _section_name(index: int) -> String:
	match clampi(index, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"


func _on_cleanup() -> void:
	changed_sections.clear()
	result_text = ""
	change_feedback_remaining = 0.0
