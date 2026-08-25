class_name SplitCascadeHandler
extends TestGimmickHandler

const SplitCascadeConfigClass = preload("res://scripts/gimmicks/configs/split_cascade_config.gd")

const MODE_SINGLE := 0
const MODE_DOUBLE := 1
const MODE_CASCADE := 2
const NORMAL_TARGET_COLOR := Color("#ffd166")
const BOSS_TARGET_COLOR := Color("#ff6b9d")

var tuning: SplitCascadeConfigClass
var enemy_mode := MODE_SINGLE
var turns_remaining := 0
var split_targets: Array[MergeBall] = []
var split_target_merge_pending := false
var collision_grace_groups: Array[Array] = []
var lifted_target: MergeBall
var lifted_target_collision_layer := 0
var lifted_target_collision_mask := 0
var lifted_target_was_frozen := false
var lifted_target_original_scale := Vector2.ONE
var lifted_target_original_modulate := Color.WHITE
var cascade_suspended_balls: Array[MergeBall] = []
var cascade_launch_velocities: Dictionary = {}


func _on_configured() -> void:
	tuning = data.tuning as SplitCascadeConfigClass
	if tuning == null:
		tuning = SplitCascadeConfigClass.new()
	_configure_enemy()


func _on_enemy_changed() -> void:
	_clear_split_targets()
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_SINGLE, MODE_CASCADE) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_CASCADE
	turns_remaining = _action_interval(enemy_index)
	_ensure_split_targets()
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	_ensure_split_targets()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		_update_feedback()
		return
	await _execute_split_attack()


func _execute_split_attack() -> void:
	busy = true
	debug_special_execution_count += 1
	merge_game.set_input_enabled(false)
	_ensure_split_targets()
	var targets: Array[MergeBall] = split_targets.duplicate()
	var intended_target_count := _target_count()
	_clear_split_targets()
	var successful_split_count := 0
	if enemy_mode == MODE_CASCADE:
		if not targets.is_empty():
			if (await _cascade_split(targets.front())):
				successful_split_count = 1
	elif enemy_mode == MODE_SINGLE:
		if not targets.is_empty():
			if (await _lift_then_split_enemy_one(targets.front())).size() == 2:
				successful_split_count = 1
	else:
		targets.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.x < b.position.x)
		for target_index in targets.size():
			var target: MergeBall = targets[target_index]
			if (await _lift_then_split_enemy_two(target)).size() == 2:
				successful_split_count += 1
			if target_index + 1 < targets.size() and tuning.enemy_two_inter_split_delay > 0.0:
				await get_tree().create_timer(tuning.enemy_two_inter_split_delay, true, false, true).timeout
	var succeeded := successful_split_count > 0
	if not succeeded:
		battle.status_label.text = "CASCADE SPLIT 실패" if enemy_mode == MODE_CASCADE else "공 분열 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		var incomplete_damage := _incomplete_split_damage()
		enemy.attack_with_damage(player, incomplete_damage)
		log_event("SPLIT INCOMPLETE", "targets=%d/%d damage=%d" % [targets.size(), intended_target_count, incomplete_damage])
	else:
		battle.status_label.text = "CASCADE SPLIT!" if enemy_mode == MODE_CASCADE else "공 분열 발동!"
		battle.status_label.modulate = Color("#ffd166")
		var split_damage_amount := _split_damage()
		if split_damage_amount > 0:
			enemy.attack_with_damage(player, split_damage_amount)
			log_event("SPLIT DAMAGE", "damage=%d" % split_damage_amount)
		if successful_split_count < intended_target_count:
			var bonus_damage := _partial_split_bonus_damage()
			if bonus_damage > 0:
				enemy.attack_with_damage(player, bonus_damage)
				log_event("PARTIAL SPLIT BONUS", "successes=%d/%d damage=%d" % [successful_split_count, intended_target_count, bonus_damage])
	turns_remaining = _action_interval(battle.current_enemy_index)
	var recovery_duration := 0.12
	if enemy_mode == MODE_SINGLE:
		recovery_duration = tuning.enemy_one_recovery_duration
	elif enemy_mode == MODE_DOUBLE:
		recovery_duration = tuning.enemy_two_recovery_duration
	elif enemy_mode == MODE_CASCADE:
		recovery_duration = tuning.boss_recovery_duration
	if recovery_duration > 0.0:
		await get_tree().create_timer(recovery_duration, true, false, true).timeout
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	busy = false
	_ensure_split_targets()
	_update_feedback()


func _lift_then_split_enemy_one(target: MergeBall) -> Array[MergeBall]:
	return await _lift_then_split_airborne(
		target,
		tuning.enemy_one_anticipation_duration,
		tuning.enemy_one_lift_min_duration,
		tuning.enemy_one_lift_max_duration,
		tuning.enemy_one_arrival_hold_duration,
		tuning.enemy_one_split_pulse_duration,
		tuning.enemy_one_split_velocity,
		tuning.enemy_one_horizontal_speed_per_radius,
		tuning.enemy_one_horizontal_speed_max
	)


func _lift_then_split_enemy_two(target: MergeBall) -> Array[MergeBall]:
	return await _lift_then_split_airborne(
		target,
		tuning.enemy_two_anticipation_duration,
		tuning.enemy_two_lift_min_duration,
		tuning.enemy_two_lift_max_duration,
		tuning.enemy_two_arrival_hold_duration,
		tuning.enemy_two_split_pulse_duration,
		tuning.enemy_one_split_velocity,
		tuning.enemy_one_horizontal_speed_per_radius,
		tuning.enemy_one_horizontal_speed_max
	)


func _lift_then_split_airborne(
	target: MergeBall,
	anticipation_duration: float,
	lift_min_duration: float,
	lift_max_duration: float,
	arrival_hold_duration: float,
	split_pulse_duration: float,
	launch_velocity: Vector2,
	horizontal_speed_per_radius: float,
	horizontal_speed_max: float,
	suspend_children: bool = false
) -> Array[MergeBall]:
	if not is_instance_valid(target) or target.merge_locked or target.merge_level <= 0:
		return []
	var bounds := merge_game.get_board_inner_bounds()
	var radius := target.get_radius()
	var minimum_x := bounds.position.x + radius
	var maximum_x := bounds.end.x - radius
	var board_safe_center_y := bounds.position.y + radius + tuning.enemy_one_board_top_margin
	# Children spawn slightly above the parent center. Keep that spawn center below the
	# Danger Line so first contact cannot immediately turn the lift into Overflow.
	var danger_safe_center_y := (
		merge_game.danger_line_y
		+ radius * tuning.normal_spawn_lift_radius_ratio
		+ tuning.enemy_one_danger_safety_margin
	)
	var high_presentation_y := maxf(board_safe_center_y, danger_safe_center_y)
	var crowded_lift_distance := minf(
		tuning.enemy_one_crowded_lift_max_distance,
		tuning.enemy_one_crowded_lift_base_distance + radius * tuning.enemy_one_crowded_lift_radius_ratio
	)
	var crowded_presentation_y := maxf(target.position.y - crowded_lift_distance, high_presentation_y)
	var stack_fill_ratio := _current_stack_fill_ratio(bounds)
	var low_fill := minf(tuning.enemy_one_stack_low_fill_ratio, tuning.enemy_one_stack_high_fill_ratio)
	var high_fill := maxf(tuning.enemy_one_stack_low_fill_ratio, tuning.enemy_one_stack_high_fill_ratio)
	var crowded_blend := smoothstep(low_fill, maxf(low_fill + 0.01, high_fill), stack_fill_ratio)
	var target_y := lerpf(high_presentation_y, crowded_presentation_y, crowded_blend)
	var presentation_x := lerpf(bounds.position.x, bounds.end.x, tuning.enemy_one_split_x_ratio)
	var target_position := Vector2(
		clampf(presentation_x, minimum_x, maximum_x),
		target_y
	)
	var travel_distance := target.position.distance_to(target_position)
	var minimum_duration := minf(lift_min_duration, lift_max_duration)
	var maximum_duration := maxf(lift_min_duration, lift_max_duration)
	var lift_duration := clampf(
		travel_distance / maxf(1.0, tuning.enemy_one_lift_speed),
		minimum_duration,
		maximum_duration
	)
	lifted_target = target
	lifted_target_collision_layer = target.collision_layer
	lifted_target_collision_mask = target.collision_mask
	lifted_target_was_frozen = target.freeze
	lifted_target_original_scale = target.scale
	lifted_target_original_modulate = target.modulate
	target.linear_velocity = Vector2.ZERO
	target.angular_velocity = 0.0
	target.freeze = true
	target.collision_layer = 0
	target.collision_mask = 0
	target.set_split_targeted(true, _split_target_color())
	var protected_duration := (
		anticipation_duration
		+ lift_duration
		+ arrival_hold_duration
		+ split_pulse_duration
		+ 0.25
	)
	merge_game.suppress_danger_line(protected_duration)
	if anticipation_duration > 0.0:
		await get_tree().create_timer(anticipation_duration, true, false, true).timeout
	if not active or not is_instance_valid(target) or target.merge_locked:
		_restore_lifted_target()
		return []
	var tween := create_gimmick_tween()
	tween.tween_property(target, "position", target_position, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not active or not is_instance_valid(target) or target.merge_locked:
		_restore_lifted_target()
		return []
	if arrival_hold_duration > 0.0:
		await get_tree().create_timer(arrival_hold_duration, true, false, true).timeout
	if not active or not is_instance_valid(target) or target.merge_locked:
		_restore_lifted_target()
		return []
	if split_pulse_duration > 0.0:
		var pulse := create_gimmick_tween()
		pulse.set_parallel(true)
		pulse.tween_property(target, "scale", lifted_target_original_scale * 1.1, split_pulse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(target, "modulate", Color("#fff1a8"), split_pulse_duration)
		await pulse.finished
	if not active or not is_instance_valid(target) or target.merge_locked:
		_restore_lifted_target()
		return []
	lifted_target = null
	return _split_once_near_parent(target, launch_velocity, horizontal_speed_per_radius, horizontal_speed_max, suspend_children)


func _current_stack_fill_ratio(bounds: Rect2) -> float:
	var uppermost_top_edge := bounds.end.y
	var found_landed_ball := false
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_queued_for_deletion() or not ball.has_landed():
			continue
		uppermost_top_edge = minf(uppermost_top_edge, _ball_top_edge(ball))
		found_landed_ball = true
	if not found_landed_ball:
		return 0.0
	var usable_height := maxf(1.0, bounds.end.y - merge_game.danger_line_y)
	var occupied_height := clampf(bounds.end.y - uppermost_top_edge, 0.0, usable_height)
	return occupied_height / usable_height


func _restore_lifted_target() -> void:
	if is_instance_valid(lifted_target) and not lifted_target.merge_locked:
		lifted_target.collision_layer = lifted_target_collision_layer
		lifted_target.collision_mask = lifted_target_collision_mask
		lifted_target.freeze = lifted_target_was_frozen
		lifted_target.scale = lifted_target_original_scale
		lifted_target.modulate = lifted_target_original_modulate
		lifted_target.set_split_targeted(false)
	lifted_target = null


func _cascade_split(target: MergeBall) -> bool:
	var parent_stage := target.merge_level + 1
	var maximum_sequence_duration := (
		tuning.boss_anticipation_duration
		+ tuning.boss_lift_max_duration
		+ tuning.boss_arrival_hold_duration
		+ tuning.boss_first_split_pulse_duration
		+ tuning.boss_first_generation_hold
		+ tuning.boss_second_split_pulse_duration
		+ tuning.boss_inter_branch_delay
		+ tuning.boss_recovery_duration
		+ 0.5
	)
	merge_game.suppress_danger_line(maximum_sequence_duration)
	var first_generation: Array[MergeBall] = await _lift_then_split_airborne(
		target,
		tuning.boss_anticipation_duration,
		tuning.boss_lift_min_duration,
		tuning.boss_lift_max_duration,
		tuning.boss_arrival_hold_duration,
		tuning.boss_first_split_pulse_duration,
		tuning.boss_first_split_velocity,
		tuning.boss_first_horizontal_speed_per_radius,
		tuning.boss_first_horizontal_speed_max,
		true
	)
	if first_generation.size() != 2:
		_release_suspended_cascade_balls()
		return false
	log_event("CASCADE STEP 1", "stage=%d -> %d + %d" % [parent_stage, parent_stage - 1, parent_stage - 1])
	if tuning.boss_first_generation_hold > 0.0:
		await get_tree().create_timer(tuning.boss_first_generation_hold, true, false, true).timeout
	if not active or not enemy.is_alive() or not player.is_alive():
		_release_suspended_cascade_balls()
		return false
	first_generation.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.x < b.position.x)
	var left_child: MergeBall = first_generation[0]
	var right_child: MergeBall = first_generation[1]
	var left_result_stage := parent_stage - 1
	var left_launch_speed := _calculate_split_horizontal_speed(
		left_child.get_radius(),
		tuning.enemy_one_split_velocity,
		tuning.enemy_one_horizontal_speed_per_radius,
		tuning.enemy_one_horizontal_speed_max
	)
	_activate_cascade_ball(left_child, Vector2(-left_launch_speed, 0.0))
	if tuning.boss_inter_branch_delay > 0.0:
		await get_tree().create_timer(tuning.boss_inter_branch_delay, true, false, true).timeout
	if not active or not is_instance_valid(right_child) or right_child.merge_locked:
		_release_suspended_cascade_balls()
		return false
	var grandchildren: Array[MergeBall] = await _pulse_then_split_cascade_branch(right_child)
	if grandchildren.size() != 2:
		_release_suspended_cascade_balls()
		return false
	log_event("CASCADE STEP 2", "left stage=%d, right branch stage=%d count=2" % [left_result_stage, grandchildren.front().merge_level + 1])
	return true


func _pulse_then_split_cascade_branch(target: MergeBall) -> Array[MergeBall]:
	if not is_instance_valid(target) or target.merge_locked or target.merge_level <= 0:
		return []
	target.set_split_targeted(true, _split_target_color())
	if tuning.boss_second_split_pulse_duration > 0.0:
		var original_scale := target.scale
		var pulse := create_gimmick_tween()
		pulse.set_parallel(true)
		pulse.tween_property(target, "scale", original_scale * 1.08, tuning.boss_second_split_pulse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(target, "modulate", Color("#fff1a8"), tuning.boss_second_split_pulse_duration)
		await pulse.finished
	if not active or not is_instance_valid(target) or target.merge_locked:
		return []
	target.set_split_targeted(false)
	cascade_suspended_balls.erase(target)
	cascade_launch_velocities.erase(target.get_instance_id())
	return _split_once_near_parent(
		target,
		tuning.enemy_one_split_velocity,
		tuning.enemy_one_horizontal_speed_per_radius,
		tuning.enemy_one_horizontal_speed_max
	)


func _split_once_near_parent(
	target: MergeBall,
	launch_velocity: Vector2,
	horizontal_speed_per_radius: float,
	horizontal_speed_max: float,
	suspend_children: bool = false
) -> Array[MergeBall]:
	var children: Array[MergeBall] = []
	if not is_instance_valid(target) or target.merge_locked or target.merge_level <= 0:
		return children
	var parent_position := target.position
	var child_level := target.merge_level - 1
	merge_game.remove_gimmick_ball(target)
	var left_child := merge_game.spawn_gimmick_ball(child_level, parent_position)
	var right_child := merge_game.spawn_gimmick_ball(child_level, parent_position)
	if not is_instance_valid(left_child) or not is_instance_valid(right_child):
		return children
	var child_radius := maxf(left_child.get_radius(), right_child.get_radius())
	var spawn_offset := maxf(tuning.normal_spawn_min_offset, child_radius * tuning.normal_spawn_offset_radius_ratio)
	if suspend_children:
		spawn_offset = child_radius + tuning.boss_first_branch_gap * 0.5
	var spawn_lift := child_radius * tuning.normal_spawn_lift_radius_ratio
	var bounds := merge_game.get_board_inner_bounds()
	var minimum_x := bounds.position.x + child_radius
	var maximum_x := bounds.end.x - child_radius
	left_child.position = Vector2(clampf(parent_position.x - spawn_offset, minimum_x, maximum_x), parent_position.y - spawn_lift)
	right_child.position = Vector2(clampf(parent_position.x + spawn_offset, minimum_x, maximum_x), parent_position.y - spawn_lift)
	var horizontal_speed := _calculate_split_horizontal_speed(
		child_radius,
		launch_velocity,
		horizontal_speed_per_radius,
		horizontal_speed_max
	)
	children.append(left_child)
	children.append(right_child)
	if suspend_children:
		_suspend_cascade_ball(left_child, Vector2.ZERO)
		_suspend_cascade_ball(right_child, Vector2.ZERO)
		return children
	left_child.linear_velocity = Vector2(-horizontal_speed, -absf(launch_velocity.y))
	right_child.linear_velocity = Vector2(horizontal_speed, -absf(launch_velocity.y))
	_apply_adaptive_sibling_grace(children)
	return children


func _calculate_split_horizontal_speed(
	radius: float,
	launch_velocity: Vector2,
	horizontal_speed_per_radius: float,
	horizontal_speed_max: float
) -> float:
	var base_speed := absf(launch_velocity.x)
	if horizontal_speed_per_radius <= 0.0:
		return base_speed
	return clampf(
		base_speed + radius * horizontal_speed_per_radius,
		base_speed,
		maxf(base_speed, horizontal_speed_max)
	)


func _suspend_cascade_ball(ball: MergeBall, launch_velocity: Vector2) -> void:
	if not is_instance_valid(ball):
		return
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.freeze = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	if not cascade_suspended_balls.has(ball):
		cascade_suspended_balls.append(ball)
	cascade_launch_velocities[ball.get_instance_id()] = launch_velocity


func _activate_cascade_ball(ball: MergeBall, launch_velocity: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(ball) or ball.merge_locked:
		return
	cascade_suspended_balls.erase(ball)
	cascade_launch_velocities.erase(ball.get_instance_id())
	ball.collision_layer = 1
	ball.collision_mask = 1
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = launch_velocity


func _release_suspended_cascade_balls() -> void:
	for ball: MergeBall in cascade_suspended_balls:
		if not is_instance_valid(ball) or ball.merge_locked:
			continue
		var launch_velocity: Vector2 = cascade_launch_velocities.get(ball.get_instance_id(), Vector2.ZERO)
		ball.collision_layer = 1
		ball.collision_mask = 1
		ball.freeze = false
		ball.sleeping = false
		ball.linear_velocity = launch_velocity
	cascade_suspended_balls.clear()
	cascade_launch_velocities.clear()


func _release_collision_grace(balls: Array[MergeBall], duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	_remove_collision_grace_group(balls)


func _apply_adaptive_sibling_grace(balls: Array[MergeBall]) -> void:
	var valid: Array[MergeBall] = []
	for ball: MergeBall in balls:
		if is_instance_valid(ball):
			valid.append(ball)
	if valid.size() < 2:
		return
	valid[0].add_collision_exception_with(valid[1])
	valid[1].add_collision_exception_with(valid[0])
	collision_grace_groups.append(valid)
	_release_adaptive_sibling_grace(valid)


func _release_adaptive_sibling_grace(balls: Array[MergeBall]) -> void:
	var started_msec := Time.get_ticks_msec()
	var minimum_msec := roundi(tuning.normal_sibling_min_grace * 1000.0)
	var maximum_msec := roundi(maxf(tuning.normal_sibling_min_grace, tuning.normal_sibling_max_grace) * 1000.0)
	while is_inside_tree() and active:
		await get_tree().physics_frame
		var elapsed_msec := Time.get_ticks_msec() - started_msec
		if elapsed_msec < minimum_msec:
			continue
		if _siblings_are_separated(balls) or elapsed_msec >= maximum_msec:
			break
	if not active:
		return
	_remove_collision_grace_group(balls)


func _siblings_are_separated(balls: Array[MergeBall]) -> bool:
	if balls.size() < 2 or not is_instance_valid(balls[0]) or not is_instance_valid(balls[1]):
		return true
	if balls[0].merge_locked or balls[1].merge_locked:
		return true
	var desired_distance := balls[0].get_radius() + balls[1].get_radius() + tuning.normal_sibling_clearance
	var bounds := merge_game.get_board_inner_bounds()
	var maximum_board_distance := maxf(0.0, (bounds.end.x - balls[1].get_radius()) - (bounds.position.x + balls[0].get_radius()))
	var required_distance := minf(desired_distance, maximum_board_distance)
	return balls[0].position.distance_to(balls[1].position) >= required_distance


func _remove_collision_grace_group(balls: Array[MergeBall]) -> void:
	for first_index in balls.size():
		if not is_instance_valid(balls[first_index]):
			continue
		for second_index in range(first_index + 1, balls.size()):
			if not is_instance_valid(balls[second_index]):
				continue
			balls[first_index].remove_collision_exception_with(balls[second_index])
			balls[second_index].remove_collision_exception_with(balls[first_index])
	collision_grace_groups.erase(balls)


func _ensure_split_targets() -> void:
	split_targets = split_targets.filter(func(ball: MergeBall) -> bool: return is_instance_valid(ball) and not ball.merge_locked)
	var target_count := _target_count()
	if split_targets.size() >= target_count:
		_update_target_marker()
		return
	var candidates: Array[MergeBall] = valid_balls(_minimum_target_stage(), tuning.maximum_target_stage)
	candidates = candidates.filter(func(ball: MergeBall) -> bool: return ball.has_landed())
	if candidates.is_empty():
		_update_target_marker()
		return
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else _ball_top_edge(a) < _ball_top_edge(b)
	)
	while split_targets.size() < target_count:
		var selected_target: MergeBall
		for candidate: MergeBall in candidates:
			if candidate in split_targets:
				continue
			if enemy_mode == MODE_DOUBLE and not split_targets.is_empty() and candidate.merge_level == split_targets.front().merge_level:
				continue
			selected_target = candidate
			break
		# Enemy 2 only falls back to a same-stage second target when no different-stage
		# candidate exists in the current upper-board candidate band.
		if selected_target == null:
			for candidate: MergeBall in candidates:
				if not (candidate in split_targets):
					selected_target = candidate
					break
		if selected_target == null:
			break
		split_targets.append(selected_target)
		selected_target.set_split_targeted(true, _split_target_color())
	_update_target_marker()


func _ball_top_edge(ball: MergeBall) -> float:
	return ball.position.y - ball.get_radius()


func _clear_split_targets() -> void:
	for target: MergeBall in split_targets:
		if is_instance_valid(target):
			target.set_split_targeted(false)
	split_targets.clear()
	split_target_merge_pending = false


func _on_merge_registered(_result_level: int, _origin: Vector2, _chain_index: int, source_ids: Array[int], _involved_cursed: bool) -> void:
	for target: MergeBall in split_targets.duplicate():
		if is_instance_valid(target) and source_ids.has(target.get_instance_id()):
			split_target_merge_pending = true
			target.set_split_targeted(false)
			split_targets.erase(target)
	_update_target_marker()


func _on_merge_completed(merged_ball: MergeBall) -> void:
	if not active or not split_target_merge_pending or not is_instance_valid(merged_ball):
		return
	merged_ball.set_split_targeted(true, _split_target_color())
	split_targets.append(merged_ball)
	split_target_merge_pending = false
	_ensure_split_targets()


func _update_target_marker() -> void:
	var marker_color := _split_target_color()
	for target: MergeBall in split_targets:
		if is_instance_valid(target) and not target.merge_locked:
			target.set_split_targeted(true, marker_color)


func _split_target_color() -> Color:
	return BOSS_TARGET_COLOR if enemy_mode == MODE_CASCADE else NORMAL_TARGET_COLOR


func _action_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.action_intervals.size():
		return maxi(1, int(tuning.action_intervals[enemy_index]))
	return maxi(1, data.action_interval)


func _partial_split_bonus_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.partial_split_bonus_damage.size():
		return maxi(0, int(tuning.partial_split_bonus_damage[enemy_index]))
	return 0


func _incomplete_split_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.incomplete_split_damage.size():
		return maxi(0, int(tuning.incomplete_split_damage[enemy_index]))
	return maxi(0, data.normal_attack_damage)


func _split_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.split_damage.size():
		return maxi(0, int(tuning.split_damage[enemy_index]))
	return maxi(0, data.normal_attack_damage)


func _minimum_target_stage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.minimum_target_stages.size():
		return clampi(int(tuning.minimum_target_stages[enemy_index]), 1, 11)
	return clampi(tuning.minimum_target_stage, 1, 11)


func _target_count() -> int:
	return 2 if enemy_mode == MODE_DOUBLE else 1


func _update_feedback() -> void:
	var action_name := "CASCADE SPLIT" if enemy_mode == MODE_CASCADE else "공 분열"
	var detail: String
	if enemy_mode == MODE_CASCADE:
		detail = "예고 공 1개 · 왼쪽 낙하 + 오른쪽 재분열"
	elif enemy_mode == MODE_DOUBLE:
		detail = "예고 공 2개 · 왼쪽부터 순차 분열"
	else:
		detail = "예고 공 1개 · 1단계 분열"
	battle.update_gimmick_ui("다음: %s · %d턴" % [action_name, turns_remaining], detail)


func _on_cleanup() -> void:
	_restore_lifted_target()
	_release_suspended_cascade_balls()
	for group: Array in collision_grace_groups:
		for first_index in group.size():
			if not is_instance_valid(group[first_index]):
				continue
			for second_index in range(first_index + 1, group.size()):
				if not is_instance_valid(group[second_index]):
					continue
				group[first_index].remove_collision_exception_with(group[second_index])
				group[second_index].remove_collision_exception_with(group[first_index])
	collision_grace_groups.clear()
	_clear_split_targets()
