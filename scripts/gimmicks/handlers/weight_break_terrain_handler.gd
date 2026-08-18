class_name WeightBreakTerrainHandler
extends TestGimmickHandler

var tuning: WeightBreakTerrainConfig
var overlay: WeightBreakTerrainOverlay
var enemy_mode := 0
var floor_bodies: Array[StaticBody2D] = []
var floor_rects: Array[Rect2] = []
var floor_names: Array[String] = []
var break_weights: Array[float] = []
var floor_loads: Array[float] = []
var floor_broken: Array[bool] = []
var result_text := ""
var refresh_elapsed := 0.0
var normal_attack_turns := 0


func _on_configured() -> void:
	tuning = data.tuning as WeightBreakTerrainConfig
	if tuning == null:
		tuning = WeightBreakTerrainConfig.new()
	overlay = attach_visual_layer(WeightBreakTerrainOverlay.new()) as WeightBreakTerrainOverlay
	_configure_floors()


func _on_enemy_changed() -> void:
	_remove_all_floors()
	result_text = ""
	normal_attack_turns = data.normal_attack_interval
	_configure_floors()
	merge_game.suppress_danger_line(0.5)


func _configure_floors() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	normal_attack_turns = data.normal_attack_interval
	if enemy_mode == 0:
		var single_width: float = bounds.size.x * tuning.single_floor_width_ratio
		var single_y: float = bounds.position.y + bounds.size.y * tuning.single_floor_height_ratio
		_add_floor("FLOOR", Rect2(Vector2(bounds.get_center().x - single_width * 0.5, single_y), Vector2(single_width, tuning.platform_thickness)), tuning.standard_break_weight)
	elif enemy_mode == 1:
		var split_width: float = bounds.size.x * tuning.split_floor_width_ratio
		var split_y: float = bounds.position.y + bounds.size.y * tuning.single_floor_height_ratio
		_add_floor("LEFT", Rect2(Vector2(bounds.position.x, split_y), Vector2(split_width, tuning.platform_thickness)), tuning.standard_break_weight)
		_add_floor("RIGHT", Rect2(Vector2(bounds.end.x - split_width, split_y), Vector2(split_width, tuning.platform_thickness)), tuning.standard_break_weight)
	else:
		var upper_width: float = bounds.size.x * tuning.single_floor_width_ratio
		var lower_width: float = bounds.size.x * 0.82
		var upper_y: float = bounds.position.y + bounds.size.y * tuning.upper_floor_height_ratio
		var lower_y: float = bounds.position.y + bounds.size.y * tuning.lower_floor_height_ratio
		_add_floor("UPPER", Rect2(Vector2(bounds.get_center().x - upper_width * 0.5, upper_y), Vector2(upper_width, tuning.platform_thickness)), tuning.standard_break_weight)
		_add_floor("LOWER", Rect2(Vector2(bounds.get_center().x - lower_width * 0.5, lower_y), Vector2(lower_width, tuning.platform_thickness)), tuning.lower_break_weight)
	_refresh_loads()
	_update_feedback()


func _add_floor(floor_name: String, floor_rect: Rect2, break_weight: float) -> void:
	var body: StaticBody2D = merge_game.spawn_one_way_platform(floor_rect, tuning.one_way_margin)
	body.name = "%sBreakFloor" % floor_name
	floor_bodies.append(body)
	floor_rects.append(floor_rect)
	floor_names.append(floor_name)
	break_weights.append(break_weight)
	floor_loads.append(0.0)
	floor_broken.append(false)


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	if not result_text.is_empty():
		result_text = ""
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_loads()
	var break_indices: Array[int] = []
	for floor_index in floor_rects.size():
		if not floor_broken[floor_index] and floor_loads[floor_index] >= break_weights[floor_index]:
			break_indices.append(floor_index)
	if not break_indices.is_empty():
		merge_game.suppress_danger_line(tuning.settle_timeout + 0.5)
		for floor_index in break_indices:
			_break_floor(floor_index)
		if tuning.collapse_delay > 0.0:
			await get_tree().create_timer(tuning.collapse_delay, true, false, true).timeout
		await merge_game.wait_until_board_settled(tuning.settle_timeout)
		_refresh_loads()
	_advance_normal_attack()
	if not player.is_alive():
		busy = false
		return
	merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _physics_process_gimmick(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 0.2:
		refresh_elapsed = 0.0
		_refresh_loads()


func _refresh_loads() -> void:
	for floor_index in floor_loads.size():
		floor_loads[floor_index] = 0.0
	for ball in valid_balls():
		for floor_index in floor_rects.size():
			if floor_broken[floor_index]:
				continue
			var floor_rect: Rect2 = floor_rects[floor_index]
			if ball.position.x < floor_rect.position.x or ball.position.x > floor_rect.end.x:
				continue
			if ball.position.y >= floor_rect.get_center().y:
				continue
			if enemy_mode == 2 and floor_index == 1 and not floor_broken[0] and ball.position.y < floor_rects[0].get_center().y:
				continue
			floor_loads[floor_index] += pow(maxf(0.01, ball.mass), tuning.stage_weight_exponent)
	_update_feedback()


func _break_floor(floor_index: int) -> void:
	if floor_index < 0 or floor_index >= floor_bodies.size() or floor_broken[floor_index]:
		return
	floor_broken[floor_index] = true
	var body: StaticBody2D = floor_bodies[floor_index]
	if is_instance_valid(body):
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		body.queue_free()
	result_text = "%s FLOOR BREAK" % floor_names[floor_index]
	battle.status_label.text = result_text
	battle.status_label.modulate = Color("#ffb86c")
	debug_special_execution_count += 1
	log_event("FLOOR BREAK", "%s %.1f / %.1f" % [floor_names[floor_index], floor_loads[floor_index], break_weights[floor_index]])
	_update_feedback()


func _advance_normal_attack() -> void:
	normal_attack_turns = maxi(0, normal_attack_turns - 1)
	if normal_attack_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		normal_attack_turns = data.normal_attack_interval


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	overlay.show_state(merge_game.get_base_board_bounds(), floor_rects, floor_names, floor_loads, break_weights, floor_broken, result_text)
	var summaries: Array[String] = []
	for floor_index in floor_names.size():
		var state_text: String = "BROKEN" if floor_broken[floor_index] else "%.1f / %.1f" % [floor_loads[floor_index], break_weights[floor_index]]
		summaries.append("%s %s" % [floor_names[floor_index], state_text])
	battle.update_gimmick_ui("WEIGHT BREAK TERRAIN", " | ".join(summaries))


func _remove_all_floors() -> void:
	for body in floor_bodies:
		if not is_instance_valid(body):
			continue
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		body.queue_free()
	floor_bodies.clear()
	floor_rects.clear()
	floor_names.clear()
	break_weights.clear()
	floor_loads.clear()
	floor_broken.clear()


func _on_cleanup() -> void:
	_remove_all_floors()
	result_text = ""
