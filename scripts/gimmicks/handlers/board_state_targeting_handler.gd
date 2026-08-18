class_name BoardStateTargetingHandler
extends TestGimmickHandler

var remaining_turns := 0
var tuning: BoardStateTargetingConfig
var overlay: BoardStateTargetingOverlay
var targeting_mode := 0
var targeting_criterion := 0
var targeting_section := -1


func _on_configured() -> void:
	tuning = data.tuning as BoardStateTargetingConfig
	if tuning == null:
		tuning = BoardStateTargetingConfig.new()
	overlay = attach_visual_layer(BoardStateTargetingOverlay.new()) as BoardStateTargetingOverlay
	var enemy_index: int = battle.current_enemy_index
	targeting_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	targeting_criterion = 1 if targeting_mode == 1 else 0
	remaining_turns = data.action_interval
	_update_target()
	_update_ui()


func _on_enemy_changed() -> void:
	var enemy_index: int = battle.current_enemy_index
	targeting_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	targeting_criterion = 1 if targeting_mode == 1 else 0
	targeting_section = -1
	remaining_turns = data.action_interval
	_update_target()
	_update_ui()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	_update_target()
	remaining_turns = maxi(0, remaining_turns - 1)
	if remaining_turns > 0:
		_update_ui()
		return
	await _execute_attack()


func _update_target() -> void:
	var metrics: Array[float] = [0.0, 0.0, 0.0]
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	for ball in valid_balls():
		var section: int = _section_for_x(ball.position.x, bounds)
		if targeting_criterion == 0:
			var stack_height: float = bounds.end.y - (ball.position.y - ball.get_radius())
			metrics[section] = maxf(metrics[section], stack_height)
		else:
			metrics[section] += 1.0
	var best_value: float = maxf(metrics[0], maxf(metrics[1], metrics[2]))
	var leaders: Array[int] = []
	for index in 3:
		if is_equal_approx(metrics[index], best_value):
			leaders.append(index)
	var previous: int = targeting_section
	if targeting_section not in leaders:
		targeting_section = leaders.front() if not leaders.is_empty() else 0
	overlay.show_target(bounds, targeting_section)
	if previous >= 0 and previous != targeting_section:
		log_event("TARGET CHANGED", "%s -> %s" % [_section_name(previous), _section_name(targeting_section)])


func _execute_attack() -> void:
	busy = true
	debug_special_execution_count += 1
	merge_game.set_input_enabled(false)
	_update_target()
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var candidates: Array[MergeBall] = []
	for ball in valid_balls():
		if _section_for_x(ball.position.x, bounds) == targeting_section:
			candidates.append(ball)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else a.position.y < b.position.y
	)
	if candidates.is_empty():
		log_event("TARGET ATTACK", "%s empty" % _section_name(targeting_section))
	else:
		var target: MergeBall = candidates.front() as MergeBall
		var old_stage: int = target.merge_level + 1
		target.modulate = Color("#ff6b6b")
		var tween: Tween = create_gimmick_tween()
		tween.tween_property(target, "modulate", Color.WHITE, 0.2)
		await tween.finished
		if is_instance_valid(target) and not target.merge_locked:
			var new_level: int = target.merge_level - tuning.stage_loss
			if new_level < 0:
				merge_game.remove_gimmick_ball(target)
			else:
				merge_game.replace_ball_stage(target, new_level)
			log_event("TARGET ATTACK", "%s stage=%d->%d" % [_section_name(targeting_section), old_stage, maxi(0, new_level + 1)])
	if targeting_mode == 2:
		targeting_criterion = 1 - targeting_criterion
		_update_target()
	remaining_turns = data.action_interval
	await get_tree().create_timer(0.12, true, false, true).timeout
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	busy = false
	_update_ui()


func _update_ui() -> void:
	var criterion_name: String = "HEIGHT" if targeting_criterion == 0 else "COUNT"
	var primary: String = "%s → %s · %d턴" % [criterion_name, _section_name(targeting_section), remaining_turns]
	var detail: String = "분석형 · 다음 기준 %s" % ("COUNT" if targeting_criterion == 0 else "HEIGHT") if targeting_mode == 2 else "보드 상태에 따라 TARGET 갱신"
	battle.update_gimmick_ui(primary, detail)


func _section_for_x(x_position: float, bounds: Rect2) -> int:
	var normalized: float = clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _section_name(section: int) -> String:
	return ["LEFT", "CENTER", "RIGHT"][clampi(section, 0, 2)]
