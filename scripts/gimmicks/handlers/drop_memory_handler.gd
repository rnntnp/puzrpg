class_name DropMemoryHandler
extends TestGimmickHandler

var tuning: DropMemoryConfig
var overlay: DropMemoryOverlay
var enemy_mode := 0
var memory: Array[int] = []
var turns_remaining := 0
var attacking_zone := -1
var result_text := ""


func _on_configured() -> void:
	tuning = data.tuning as DropMemoryConfig
	if tuning == null:
		tuning = DropMemoryConfig.new()
	overlay = attach_visual_layer(DropMemoryOverlay.new()) as DropMemoryOverlay
	_configure_enemy()


func _on_enemy_changed() -> void:
	memory.clear()
	attacking_zone = -1
	result_text = ""
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	turns_remaining = _attack_interval(enemy_index)
	_update_feedback()


func _on_player_ball_landed(_level: int, drop_x: float) -> void:
	if not active or busy or not enemy.is_alive():
		return
	var zone_index: int = _zone_for_x(drop_x)
	if enemy_mode == 0:
		memory.clear()
		memory.append(zone_index)
	elif enemy_mode == 1:
		memory.append(zone_index)
		while memory.size() > 2:
			memory.pop_front()
	else:
		if memory.size() < 3:
			memory.append(zone_index)
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		await _replay_memory()
		if not active or not enemy.is_alive() or not player.is_alive():
			busy = false
			return
		if enemy_mode == 2:
			memory.clear()
		turns_remaining = _attack_interval(battle.current_enemy_index)
		attacking_zone = -1
		await get_tree().create_timer(tuning.feedback_duration, true, false, true).timeout
		result_text = ""
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _replay_memory() -> void:
	debug_special_execution_count += 1
	var replay: Array[int] = memory.duplicate()
	if replay.is_empty():
		result_text = "MEMORY EMPTY"
		_update_feedback()
		return
	for zone_index in replay:
		attacking_zone = zone_index
		var target: MergeBall = _highest_stage_ball(zone_index)
		if target == null:
			result_text = "%s · MISS" % _zone_name(zone_index)
		else:
			var previous_stage: int = target.merge_level + 1
			if target.merge_level <= 0:
				merge_game.remove_gimmick_ball(target)
			else:
				merge_game.replace_ball_stage(target, target.merge_level - 1)
			result_text = "%s · STAGE %d → %d" % [_zone_name(zone_index), previous_stage, maxi(0, previous_stage - 1)]
		battle.status_label.text = "MEMORY ATTACK: %s" % _zone_name(zone_index)
		battle.status_label.modulate = Color("#ffb86c")
		log_event("MEMORY ATTACK", result_text)
		_update_feedback()
		if tuning.attack_step_interval > 0.0:
			await get_tree().create_timer(tuning.attack_step_interval, true, false, true).timeout


func _highest_stage_ball(zone_index: int) -> MergeBall:
	var selected: MergeBall
	var selected_level := -1
	var selected_y := INF
	for ball in valid_balls():
		if _zone_for_x(ball.position.x) != zone_index:
			continue
		if ball.merge_level > selected_level or (ball.merge_level == selected_level and ball.position.y < selected_y):
			selected = ball
			selected_level = ball.merge_level
			selected_y = ball.position.y
	return selected


func _zone_for_x(x_value: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	return clampi(floori((x_value - bounds.position.x) / (bounds.size.x / 3.0)), 0, 2)


func _attack_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.attack_intervals.size():
		return maxi(1, tuning.attack_intervals[enemy_index])
	return 3


func _memory_text(with_placeholders: bool) -> String:
	var entries: Array[String] = []
	for zone_index in memory:
		entries.append(_zone_short_name(zone_index))
	if with_placeholders and enemy_mode == 2:
		while entries.size() < 3:
			entries.append("?")
	return " → ".join(entries) if not entries.is_empty() else "—"


func _zone_name(zone_index: int) -> String:
	if zone_index == 0:
		return "LEFT"
	if zone_index == 1:
		return "CENTER"
	return "RIGHT"


func _zone_short_name(zone_index: int) -> String:
	if zone_index == 0:
		return "L"
	if zone_index == 1:
		return "C"
	return "R"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	overlay.show_state(merge_game.get_base_board_bounds(), memory, enemy_mode, turns_remaining, attacking_zone, result_text)
	var label_name: String = "REPLAY" if enemy_mode == 2 else "MEMORY"
	battle.update_gimmick_ui("%s · %d턴" % [label_name, turns_remaining], "%s: %s" % [label_name, _memory_text(true)])


func _on_cleanup() -> void:
	memory.clear()
	attacking_zone = -1
	result_text = ""

