class_name WeightBreakTerrainHandler
extends TestGimmickHandler

enum GlassState { NORMAL, CRACKED, DESTROYED }

var tuning: WeightBreakTerrainConfig
var overlay: GlassRiseOverlay

# Enemy 1 owns C1-C3. They remain in the board when the next enemy starts.
var central_bodies: Array[StaticBody2D] = []
var central_states: Array[int] = []
var central_loads: Array[int] = []
var central_rects: Array[Rect2] = []

# Enemy 2 owns L1/L2 and R1/R2. Indexes 0/1 are left, 2/3 are right.
var side_bodies: Array[StaticBody2D] = []
var side_states: Array[int] = []
var side_loads: Array[int] = []
var side_rects: Array[Rect2] = []

var action_turns_remaining: int = 0
var awaiting_full_attack: bool = false
var result_text: String = ""


func _on_configured() -> void:
	tuning = data.tuning as WeightBreakTerrainConfig
	if tuning == null:
		tuning = WeightBreakTerrainConfig.new()
	overlay = attach_visual_layer(GlassRiseOverlay.new()) as GlassRiseOverlay
	_ensure_central_slots()
	_ensure_side_slots()
	_reset_action_schedule()
	_update_feedback()


func _on_enemy_changed() -> void:
	# Enemy 1 ends by releasing its single central glass. Enemy 2 therefore
	# starts its twin-side lesson with the player's board, but no central support.
	if battle.current_enemy_index == 1:
		_release_central_glass_for_enemy_transition()
	_reset_action_schedule()
	result_text = ""
	_update_feedback()
	merge_game.suppress_danger_line(0.5)


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	await _evaluate_glass_after_settlement()
	action_turns_remaining = maxi(0, action_turns_remaining - 1)
	if action_turns_remaining <= 0:
		merge_game.set_input_enabled(false)
		if _has_active_capacity():
			if _uses_side_glass():
				await _rise_side_glass()
			elif _uses_tutorial_central_glass():
				await _advance_tutorial_central_glass()
			else:
				await _rise_central_glass()
			await _evaluate_glass_after_settlement()
			awaiting_full_attack = not _has_active_capacity()
			action_turns_remaining = tuning.full_glass_attack_interval if awaiting_full_attack else tuning.glass_rise_action_interval
		else:
			_advance_normal_attack()
			awaiting_full_attack = true
			action_turns_remaining = tuning.full_glass_attack_interval
		if active and enemy.is_alive() and player.is_alive():
			await _evaluate_glass_after_settlement()
			if _has_active_capacity() and awaiting_full_attack:
				action_turns_remaining = tuning.glass_rise_action_interval
				awaiting_full_attack = false
		merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _evaluate_glass_after_settlement() -> void:
	if not active or not is_instance_valid(merge_game):
		return
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active:
		return
	_refresh_all_loads()
	var destroyed_any: bool = _check_all_glass_damage()
	if destroyed_any:
		# A collapse may trigger normal merges and transfer load to a lower glass.
		await merge_game.wait_until_board_settled(tuning.settle_timeout)
		if active:
			_refresh_all_loads()
			_check_all_glass_damage()
	if _has_active_capacity() and awaiting_full_attack:
		action_turns_remaining = tuning.glass_rise_action_interval
		awaiting_full_attack = false
	_update_feedback()


func _uses_side_glass() -> bool:
	# Enemy 2 alone owns the side slots.
	return battle.current_enemy_index == 1


func _uses_tutorial_central_glass() -> bool:
	# Enemy 1 teaches one glass: create it, then only move that same glass up.
	return battle.current_enemy_index == 0


func _reset_action_schedule() -> void:
	action_turns_remaining = tuning.glass_rise_action_interval
	awaiting_full_attack = false


func _has_active_capacity() -> bool:
	if _uses_side_glass():
		return _has_side_capacity()
	if _uses_tutorial_central_glass():
		return _has_tutorial_central_capacity()
	# Enemy 3 is the pressure version: every empty central slot is refillable.
	return _first_empty_central_index() >= 0


func _has_tutorial_central_capacity() -> bool:
	var highest_index: int = _highest_central_index()
	return highest_index < 2


func _advance_tutorial_central_glass() -> void:
	result_text = "GLASS RISE"
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	var highest_index: int = _highest_central_index()
	if highest_index < 0:
		_create_central_glass(0)
		return
	if highest_index < 2:
		await _move_central_glass(highest_index, highest_index + 1)


func _rise_central_glass() -> void:
	result_text = "GLASS RISE"
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	var empty_index: int = _first_empty_central_index()
	if empty_index < 0:
		return
	for index in range(empty_index, 0, -1):
		var source_index: int = index - 1
		if not is_instance_valid(central_bodies[source_index]):
			continue
		await _move_central_glass(source_index, index)
	_create_central_glass(0)


func _move_central_glass(source_index: int, target_index: int) -> void:
	var source: StaticBody2D = central_bodies[source_index]
	if not is_instance_valid(source):
		return
	var target_rect: Rect2 = _make_central_rect(target_index)
	await _move_glass_with_supported_balls(source, central_rects[source_index], target_rect)
	central_bodies[target_index] = source
	central_states[target_index] = central_states[source_index]
	central_loads[target_index] = central_loads[source_index]
	central_rects[target_index] = target_rect
	central_bodies[source_index] = null
	central_states[source_index] = GlassState.NORMAL
	central_loads[source_index] = 0
	central_rects[source_index] = Rect2()


func _rise_side_glass() -> void:
	result_text = "SIDE GLASS RISE"
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	# Each side is independent. A full side is simply skipped.
	await _rise_one_side(0)
	await _rise_one_side(2)


func _rise_one_side(lower_index: int) -> void:
	var upper_index: int = lower_index + 1
	var has_lower: bool = is_instance_valid(side_bodies[lower_index])
	var has_upper: bool = is_instance_valid(side_bodies[upper_index])
	if not has_lower and not has_upper:
		_create_side_glass(lower_index)
		return
	if not has_lower or has_upper:
		return
	var source: StaticBody2D = side_bodies[lower_index]
	var target_rect: Rect2 = _make_side_rect(upper_index)
	await _move_glass_with_supported_balls(source, side_rects[lower_index], target_rect)
	side_bodies[upper_index] = source
	side_states[upper_index] = side_states[lower_index]
	side_loads[upper_index] = side_loads[lower_index]
	side_rects[upper_index] = target_rect
	side_bodies[lower_index] = null
	side_states[lower_index] = GlassState.NORMAL
	side_loads[lower_index] = 0
	side_rects[lower_index] = Rect2()


func _move_glass_with_supported_balls(body: StaticBody2D, source_rect: Rect2, target_rect: Rect2) -> void:
	var carried_balls: Array[MergeBall] = _get_supported_balls(source_rect)
	var target_y: float = target_rect.get_center().y
	var offset_y: float = target_y - body.position.y
	var tween: Tween = create_gimmick_tween().set_parallel(true)
	tween.tween_property(body, "position:y", target_y, tuning.movement_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for ball in carried_balls:
		if is_instance_valid(ball):
			tween.tween_property(ball, "position:y", ball.position.y + offset_y, tuning.movement_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _first_empty_central_index() -> int:
	for index in range(3):
		if not is_instance_valid(central_bodies[index]):
			return index
	return -1


func _highest_central_index() -> int:
	for index in range(2, -1, -1):
		if is_instance_valid(central_bodies[index]):
			return index
	return -1


func _has_side_capacity() -> bool:
	return _side_can_rise(0) or _side_can_rise(2)


func _side_can_rise(lower_index: int) -> bool:
	var has_lower: bool = is_instance_valid(side_bodies[lower_index])
	var has_upper: bool = is_instance_valid(side_bodies[lower_index + 1])
	return (not has_lower and not has_upper) or (has_lower and not has_upper)


func _create_central_glass(index: int) -> void:
	var rect: Rect2 = _make_central_rect(index)
	var body: StaticBody2D = _create_glass_body(rect, "GlassC%d" % (index + 1))
	central_bodies[index] = body
	central_states[index] = GlassState.NORMAL
	central_loads[index] = 0
	central_rects[index] = rect


func _create_side_glass(index: int) -> void:
	var rect: Rect2 = _make_side_rect(index)
	var body: StaticBody2D = _create_glass_body(rect, "Glass%s" % _side_slot_name(index))
	side_bodies[index] = body
	side_states[index] = GlassState.NORMAL
	side_loads[index] = 0
	side_rects[index] = rect


func _create_glass_body(rect: Rect2, node_name: String) -> StaticBody2D:
	var body: StaticBody2D = merge_game.spawn_one_way_platform(rect, tuning.one_way_margin)
	body.name = node_name
	var glass_visual := Polygon2D.new()
	glass_visual.name = "GlassVisual"
	glass_visual.polygon = PackedVector2Array([
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5), Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5), Vector2(-rect.size.x * 0.5, rect.size.y * 0.5),
	])
	glass_visual.color = Color(0.35, 0.88, 1.0, 0.72)
	glass_visual.z_index = 4
	body.add_child(glass_visual)
	var glass_edge := Line2D.new()
	glass_edge.name = "GlassEdge"
	glass_edge.points = PackedVector2Array([
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5), Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5), Vector2(-rect.size.x * 0.5, rect.size.y * 0.5),
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
	])
	glass_edge.width = 3.0
	glass_edge.default_color = Color(0.65, 0.95, 1.0, 0.95)
	glass_edge.z_index = 5
	body.add_child(glass_edge)
	return body


func _make_central_rect(index: int) -> Rect2:
	var bounds: Rect2 = merge_game.get_playable_board_bounds()
	var width_ratio: float = tuning.enemy1_glass_width_ratio if _uses_tutorial_central_glass() else tuning.glass_width_ratio
	var width: float = bounds.size.x * width_ratio
	return Rect2(Vector2(bounds.get_center().x - width * 0.5, _central_glass_y(index)), Vector2(width, tuning.glass_thickness))


func _make_side_rect(index: int) -> Rect2:
	var bounds: Rect2 = merge_game.get_playable_board_bounds()
	var width: float = bounds.size.x * tuning.side_glass_width_ratio
	var is_left: bool = index < 2
	var outer_margin: float = bounds.size.x * tuning.side_outer_margin_ratio
	var x: float = bounds.position.x + outer_margin if is_left else bounds.end.x - outer_margin - width
	var y: float = _side_glass_y(index % 2)
	return Rect2(Vector2(x, y), Vector2(width, tuning.glass_thickness))


func _central_glass_y(index: int) -> float:
	var bounds: Rect2 = merge_game.get_playable_board_bounds()
	var ratio: float = tuning.c1_height_ratio if index == 0 else (tuning.c2_height_ratio if index == 1 else tuning.c3_height_ratio)
	return lerpf(bounds.position.y, bounds.end.y, ratio)


func _side_glass_y(slot_index: int) -> float:
	var bounds: Rect2 = merge_game.get_playable_board_bounds()
	var ratio: float = tuning.side_lower_height_ratio if slot_index == 0 else tuning.side_upper_height_ratio
	return lerpf(bounds.position.y, bounds.end.y, ratio)


func _refresh_all_loads() -> void:
	_refresh_group_loads(central_bodies, central_states, central_loads, central_rects)
	_refresh_group_loads(side_bodies, side_states, side_loads, side_rects)


func _refresh_group_loads(bodies: Array[StaticBody2D], states: Array[int], loads: Array[int], rects: Array[Rect2]) -> void:
	for index in loads.size():
		loads[index] = 0
	var balls: Array[MergeBall] = valid_balls()
	for index in bodies.size():
		if not is_instance_valid(bodies[index]) or states[index] == GlassState.DESTROYED:
			continue
		var rect: Rect2 = rects[index]
		var supported: Array[MergeBall] = _get_supported_balls(rect, balls)
		for ball in supported:
			loads[index] += ball.merge_level + 1


func _get_supported_balls(rect: Rect2, candidates: Array[MergeBall] = []) -> Array[MergeBall]:
	var balls: Array[MergeBall] = candidates if not candidates.is_empty() else valid_balls()
	var supported: Array[MergeBall] = []
	for ball in balls:
		if _is_touching_glass(ball, rect):
			supported.append(ball)
	var found_connected: bool = true
	while found_connected:
		found_connected = false
		for candidate in balls:
			if candidate in supported:
				continue
			for base in supported:
				if _is_resting_on_ball(candidate, base):
					supported.append(candidate)
					found_connected = true
					break
	return supported


func _is_touching_glass(ball: MergeBall, rect: Rect2) -> bool:
	var radius: float = ball.get_radius()
	var margin: float = tuning.support_contact_margin
	var within_width: bool = ball.position.x + radius >= rect.position.x and ball.position.x - radius <= rect.end.x
	var touches_top: bool = ball.position.y + radius >= rect.position.y - margin and ball.position.y <= rect.position.y + margin
	return within_width and touches_top


func _is_resting_on_ball(candidate: MergeBall, base: MergeBall) -> bool:
	if candidate.position.y > base.position.y + tuning.support_contact_margin:
		return false
	var contact_distance: float = candidate.get_radius() + base.get_radius() + tuning.support_contact_margin
	return candidate.position.distance_to(base.position) <= contact_distance


func _check_all_glass_damage() -> bool:
	var central_destroyed: bool = _check_group_damage(central_bodies, central_states, central_loads, ["C1", "C2", "C3"], tuning.crack_stage_sum, tuning.destroy_stage_sum)
	var side_destroyed: bool = _check_group_damage(side_bodies, side_states, side_loads, ["L1", "L2", "R1", "R2"], tuning.side_crack_stage_sum, tuning.side_destroy_stage_sum)
	return central_destroyed or side_destroyed


func _check_group_damage(bodies: Array[StaticBody2D], states: Array[int], loads: Array[int], names: Array[String], crack_threshold: int, destroy_threshold: int) -> bool:
	var destroyed_any: bool = false
	for index in bodies.size():
		if not is_instance_valid(bodies[index]) or states[index] == GlassState.DESTROYED:
			continue
		if loads[index] >= destroy_threshold:
			_destroy_glass(bodies, states, loads, names[index], index)
			destroyed_any = true
		elif loads[index] >= crack_threshold:
			states[index] = GlassState.CRACKED
		_update_glass_visual(bodies[index], states[index])
	return destroyed_any


func _update_glass_visual(body: StaticBody2D, state: int) -> void:
	if not is_instance_valid(body):
		return
	var visual: Polygon2D = body.get_node_or_null("GlassVisual") as Polygon2D
	var edge: Line2D = body.get_node_or_null("GlassEdge") as Line2D
	var color: Color = Color(0.35, 0.88, 1.0, 0.72) if state == GlassState.NORMAL else Color(1.0, 0.72, 0.25, 0.76)
	if is_instance_valid(visual):
		visual.color = color
	if is_instance_valid(edge):
		edge.default_color = Color(1.0, 0.9, 0.5, 0.98) if state == GlassState.CRACKED else Color(0.65, 0.95, 1.0, 0.95)


func _destroy_glass(bodies: Array[StaticBody2D], states: Array[int], loads: Array[int], slot_name: String, index: int) -> void:
	states[index] = GlassState.DESTROYED
	result_text = "%s GLASS DESTROYED" % slot_name
	var body: StaticBody2D = bodies[index]
	bodies[index] = null
	if is_instance_valid(body):
		body.queue_free()
	debug_special_execution_count += 1
	log_event("GLASS DESTROYED", "%s load=%d" % [slot_name, loads[index]])


func _release_central_glass_for_enemy_transition() -> void:
	for index in central_bodies.size():
		var body: StaticBody2D = central_bodies[index]
		if is_instance_valid(body):
			body.queue_free()
		central_bodies[index] = null
		central_states[index] = GlassState.NORMAL
		central_loads[index] = 0
		central_rects[index] = Rect2()


func _advance_normal_attack() -> void:
	enemy.attack_with_damage(player, data.normal_attack_damage)


func _update_feedback() -> void:
	if not is_instance_valid(overlay):
		return
	var all_rects: Array[Rect2] = []
	var all_states: Array[int] = []
	var all_loads: Array[int] = []
	var all_names: Array[String] = []
	var all_destroy_thresholds: Array[int] = []
	if not _uses_side_glass() or _has_central_glass():
		_append_feedback_group(all_rects, all_states, all_loads, all_names, central_rects, central_states, central_loads, ["C1", "C2", "C3"])
	if _uses_side_glass() or _has_side_history():
		_append_feedback_group(all_rects, all_states, all_loads, all_names, side_rects, side_states, side_loads, ["L1", "L2", "R1", "R2"])
	for slot_name in all_names:
		all_destroy_thresholds.append(tuning.side_destroy_stage_sum if slot_name.begins_with("L") or slot_name.begins_with("R") else tuning.destroy_stage_sum)
	overlay.show_state(merge_game.get_playable_board_bounds(), all_rects, all_names, all_states, all_loads, tuning.crack_stage_sum, all_destroy_thresholds, result_text)
	var state_texts: Array[String] = []
	for index in all_names.size():
		var state_name: String = "DESTROYED" if all_states[index] == GlassState.DESTROYED else ("CRACKED" if all_states[index] == GlassState.CRACKED else "NORMAL")
		var slot_destroy_threshold: int = tuning.side_destroy_stage_sum if all_names[index].begins_with("L") or all_names[index].begins_with("R") else tuning.destroy_stage_sum
		state_texts.append("%s %s %d/%d" % [all_names[index], state_name, all_loads[index], slot_destroy_threshold])
	var next_action: String = _next_action_text()
	var primary: String = "%s · %d턴" % [next_action, action_turns_remaining]
	if not result_text.is_empty():
		primary = "%s · %s" % [result_text, primary]
	battle.update_gimmick_ui(primary, " | ".join(state_texts))


func _next_action_text() -> String:
	if not _has_active_capacity():
		return "다음 일반 공격"
	if _uses_side_glass():
		return "다음 좌우 유리 생성"
	if _uses_tutorial_central_glass():
		return "다음 유리 상승" if _highest_central_index() >= 0 else "다음 유리 생성"
	return "다음 중앙 유리 생성"


func _append_feedback_group(target_rects: Array[Rect2], target_states: Array[int], target_loads: Array[int], target_names: Array[String], rects: Array[Rect2], states: Array[int], loads: Array[int], names: Array[String]) -> void:
	for index in names.size():
		target_rects.append(rects[index])
		target_states.append(states[index])
		target_loads.append(loads[index])
		target_names.append(names[index])


func _side_slot_name(index: int) -> String:
	return ["L1", "L2", "R1", "R2"][index]


func _has_side_history() -> bool:
	for rect in side_rects:
		if rect.size != Vector2.ZERO:
			return true
	return false


func _has_central_glass() -> bool:
	for body in central_bodies:
		if is_instance_valid(body):
			return true
	return false


func _ensure_central_slots() -> void:
	while central_bodies.size() < 3:
		central_bodies.append(null)
		central_states.append(GlassState.NORMAL)
		central_loads.append(0)
		central_rects.append(Rect2())


func _ensure_side_slots() -> void:
	while side_bodies.size() < 4:
		side_bodies.append(null)
		side_states.append(GlassState.NORMAL)
		side_loads.append(0)
		side_rects.append(Rect2())


func _remove_all_glass() -> void:
	for body in central_bodies:
		if is_instance_valid(body):
			body.queue_free()
	for body in side_bodies:
		if is_instance_valid(body):
			body.queue_free()
	central_bodies.clear()
	central_states.clear()
	central_loads.clear()
	central_rects.clear()
	side_bodies.clear()
	side_states.clear()
	side_loads.clear()
	side_rects.clear()


func _on_cleanup() -> void:
	_remove_all_glass()
	result_text = ""
