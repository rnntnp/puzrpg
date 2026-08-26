class_name SplitCascadeHandler
extends TestGimmickHandler

const SplitCascadeConfigClass = preload("res://scripts/gimmicks/configs/split_cascade_config.gd")
const SplitCountdownEffect: StatusEffectData = preload("res://resources/effects/split_countdown.tres")
const FishingReelSfx: AudioStream = preload("res://assets/audio/sfx/fishing_reel_wind.ogg")

const MODE_SINGLE := 0
const MODE_DOUBLE := 1
const MODE_CASCADE := 2
const DEFAULT_TARGET_COLOR := Color("#ffd166")
const MERGE_RESULT_GRACE_MSEC := 500

var tuning: SplitCascadeConfigClass
var enemy_mode := MODE_SINGLE
var turns_remaining := 0
var split_targets: Array[MergeBall] = []
var pending_merge_target_slots: Array[int] = []
var pending_split_target_slots := 0
var split_cast_resolution_active := false
var reserved_split_target_states: Dictionary = {}
var collision_grace_groups: Array[Array] = []
var lifted_target: MergeBall
var lifted_target_collision_layer := 0
var lifted_target_collision_mask := 0
var lifted_target_was_frozen := false
var lifted_target_original_scale := Vector2.ONE
var lifted_target_original_modulate := Color.WHITE
var cascade_suspended_balls: Array[MergeBall] = []
var cascade_launch_velocities: Dictionary = {}
var fishing_reel_players: Array[AudioStreamPlayer] = []
var double_reel_index := 0
var split_cast_sequence_id := 0
var split_cast_committed := false
var deferred_enemy_configuration := false
var committed_split_target_color := DEFAULT_TARGET_COLOR


func _on_configured() -> void:
	if fishing_reel_players.is_empty():
		for _index in 2:
			var reel_player := AudioStreamPlayer.new()
			reel_player.stream = FishingReelSfx
			reel_player.volume_db = -7.0
			add_child(reel_player)
			fishing_reel_players.append(reel_player)
	tuning = data.tuning as SplitCascadeConfigClass
	if tuning == null:
		tuning = SplitCascadeConfigClass.new()
	_configure_enemy()


func _on_enemy_changed() -> void:
	if split_cast_committed:
		# A committed split belongs to the outgoing enemy. Let it finish against its
		# snapshotted board targets, then configure the newly loaded enemy.
		deferred_enemy_configuration = true
		busy = true
		return
	_cancel_uncommitted_split_cast()
	_release_split_target_reservations()
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
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		_ensure_split_targets()
		_update_feedback()
		return
	await _execute_split_attack()


func should_finish_committed_action_after_enemy_defeat() -> bool:
	return split_cast_committed


func _on_player_ball_dropped() -> void:
	if not active or busy or turns_remaining != 1:
		return
	if not is_instance_valid(enemy) or not enemy.is_alive() or not is_instance_valid(player) or not player.is_alive():
		return
	# The action-triggering drop owns the final response window. Lock now so its
	# first contact cannot reopen input before turn_completed resolves the cast.
	merge_game.set_input_enabled(false)


func _execute_split_attack() -> void:
	split_cast_sequence_id += 1
	var cast_sequence_id := split_cast_sequence_id
	split_cast_committed = false
	deferred_enemy_configuration = false
	busy = true
	battle.right_status_effects.remove_effect(SplitCountdownEffect.effect_id)
	battle.clear_player_damage_preview()
	debug_special_execution_count += 1
	merge_game.set_input_enabled(false)
	var targets: Array[MergeBall] = await _resolve_split_cast_targets(cast_sequence_id)
	if not _is_precommit_cast_valid(cast_sequence_id):
		return
	var intended_target_count := _target_count()
	if targets.is_empty():
		var incomplete_damage := _incomplete_split_damage()
		if incomplete_damage > 0:
			enemy.attack_with_damage(player, incomplete_damage)
			log_event("SPLIT INCOMPLETE", "targets=0/%d damage=%d" % [intended_target_count, incomplete_damage])
		_finish_uncommitted_split_action()
		return
	_commit_split_cast(targets, intended_target_count)
	if not is_instance_valid(player) or not player.is_alive():
		_release_split_target_reservations()
		split_cast_committed = false
		busy = false
		return
	double_reel_index = 0
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
			# 첫 번째 분열의 물리 반응이나 합체로 다음 대상이 제거될 수 있다.
			# 해제된 typed 객체를 함수에 넘기기 전에 매 순서마다 다시 검증한다.
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.merge_locked:
				continue
			if (await _lift_then_split_enemy_two(target)).size() == 2:
				successful_split_count += 1
			if target_index + 1 < targets.size() and tuning.enemy_two_inter_split_delay > 0.0:
				await get_tree().create_timer(tuning.enemy_two_inter_split_delay, true, false, true).timeout
	if successful_split_count > 0:
		if not deferred_enemy_configuration and is_instance_valid(enemy) and enemy.is_alive():
			battle.status_label.text = "CASCADE SPLIT!" if enemy_mode == MODE_CASCADE else "공 분열 발동!"
			battle.status_label.modulate = Color("#ffd166")
	else:
		if not deferred_enemy_configuration and is_instance_valid(enemy) and enemy.is_alive():
			battle.status_label.text = "CASCADE SPLIT 실패" if enemy_mode == MODE_CASCADE else "공 분열 실패"
			battle.status_label.modulate = Color("#ff6b6b")
		log_event("SPLIT ANIMATION INCOMPLETE", "targets=%d/%d" % [targets.size(), intended_target_count])
	if not deferred_enemy_configuration and is_instance_valid(enemy) and enemy.is_alive():
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
	_release_split_target_reservations()
	if deferred_enemy_configuration:
		_finish_deferred_enemy_configuration()
		return
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	if is_instance_valid(enemy):
		enemy.clear_visual_override()
	busy = false
	split_cast_committed = false
	if active and enemy.is_alive() and player.is_alive():
		_ensure_split_targets()
		_update_feedback()


func _resolve_split_cast_targets(cast_sequence_id: int) -> Array[MergeBall]:
	split_cast_resolution_active = true
	_reserve_ready_split_targets()
	await _wait_for_pending_split_merge_results()
	if not _is_precommit_cast_valid(cast_sequence_id):
		split_cast_resolution_active = false
		return []
	_abandon_pending_split_target_slots()
	_prune_unusable_split_targets()
	_ensure_split_targets()
	_reserve_ready_split_targets()
	var resolved_targets: Array[MergeBall] = split_targets.duplicate()
	split_cast_resolution_active = false
	return resolved_targets


func _is_precommit_cast_valid(cast_sequence_id: int) -> bool:
	return (
		active
		and cast_sequence_id == split_cast_sequence_id
		and not split_cast_committed
		and is_instance_valid(enemy)
		and enemy.is_alive()
		and is_instance_valid(player)
		and player.is_alive()
	)


func _commit_split_cast(targets: Array[MergeBall], intended_target_count: int) -> void:
	committed_split_target_color = _split_target_color()
	split_cast_committed = true
	if enemy.character_data.cast_sprite != null:
		enemy.set_visual_override(enemy.character_data.cast_sprite)
	enemy.play_cast_animation()
	var damage := _split_damage()
	if targets.size() < intended_target_count:
		damage += _partial_split_bonus_damage()
	if damage > 0:
		enemy.attack_with_damage(player, damage)
		log_event("SPLIT DAMAGE", "targets=%d/%d damage=%d" % [targets.size(), intended_target_count, damage])


func _finish_uncommitted_split_action() -> void:
	_release_split_target_reservations()
	_clear_split_targets()
	if active and is_instance_valid(enemy) and enemy.is_alive() and is_instance_valid(player) and player.is_alive():
		turns_remaining = _action_interval(battle.current_enemy_index)
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
		_ensure_split_targets()
		_update_feedback()
	busy = false


func _finish_deferred_enemy_configuration() -> void:
	split_cast_committed = false
	deferred_enemy_configuration = false
	committed_split_target_color = DEFAULT_TARGET_COLOR
	busy = false
	_clear_split_targets()
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not is_instance_valid(player) or not player.is_alive():
		return
	_configure_enemy()
	merge_game.set_input_enabled(true)


func _cancel_uncommitted_split_cast() -> void:
	split_cast_sequence_id += 1
	split_cast_committed = false
	deferred_enemy_configuration = false
	committed_split_target_color = DEFAULT_TARGET_COLOR
	split_cast_resolution_active = false
	for reel_player in fishing_reel_players:
		if is_instance_valid(reel_player):
			reel_player.stop()


func _wait_for_pending_split_merge_results() -> void:
	var deadline := Time.get_ticks_msec() + MERGE_RESULT_GRACE_MSEC
	while (
		active
		and (pending_split_target_slots > 0 or _has_locked_split_targets())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().physics_frame


func _has_locked_split_targets() -> bool:
	for target: MergeBall in split_targets:
		if is_instance_valid(target) and target.merge_locked:
			return true
	return false


func _abandon_pending_split_target_slots() -> void:
	if pending_split_target_slots <= 0:
		return
	for index in pending_merge_target_slots.size():
		if pending_merge_target_slots[index] > 0:
			pending_merge_target_slots[index] = 0
	pending_split_target_slots = 0


func _prune_unusable_split_targets() -> void:
	for target: MergeBall in split_targets.duplicate():
		if _is_valid_split_target(target):
			continue
		if is_instance_valid(target):
			target.set_split_targeted(false)
		split_targets.erase(target)


func _reserve_ready_split_targets() -> void:
	for target: MergeBall in split_targets:
		_reserve_split_target(target)


func _reserve_split_target(target: MergeBall) -> void:
	if not _is_valid_split_target(target):
		return
	var target_id := target.get_instance_id()
	if reserved_split_target_states.has(target_id):
		return
	reserved_split_target_states[target_id] = {
		"target_id": target_id,
		"collision_layer": target.collision_layer,
		"collision_mask": target.collision_mask,
		"freeze": target.freeze,
		"sleeping": target.sleeping,
		"linear_velocity": target.linear_velocity,
		"angular_velocity": target.angular_velocity,
	}
	target.set_split_cast_reserved(true)
	target.linear_velocity = Vector2.ZERO
	target.angular_velocity = 0.0
	target.freeze = true
	target.collision_layer = 0
	target.collision_mask = 0


func _release_split_target_reservations() -> void:
	for state: Dictionary in reserved_split_target_states.values():
		var target_id := int(state.get("target_id", 0))
		var target := instance_from_id(target_id) as MergeBall if target_id > 0 else null
		if not is_instance_valid(target):
			continue
		target.set_split_cast_reserved(false)
		if target.merge_locked:
			continue
		target.collision_layer = int(state.get("collision_layer", 1))
		target.collision_mask = int(state.get("collision_mask", 1))
		target.freeze = bool(state.get("freeze", false))
		target.sleeping = bool(state.get("sleeping", false))
		var stored_linear_velocity: Vector2 = state.get("linear_velocity", Vector2.ZERO)
		target.linear_velocity = stored_linear_velocity
		target.angular_velocity = float(state.get("angular_velocity", 0.0))
	reserved_split_target_states.clear()


func _is_valid_split_target(target: MergeBall) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.merge_locked:
		return false
	var stage := target.merge_level + 1
	return stage >= _minimum_target_stage() and stage <= tuning.maximum_target_stage


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
	var result := await _lift_then_split_airborne(
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
	double_reel_index += 1
	return result


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
	var active_reel_player := _play_lift_reel()
	if enemy_mode == MODE_CASCADE and is_instance_valid(active_reel_player):
		var reel_pitch_swing := create_gimmick_tween()
		reel_pitch_swing.tween_property(active_reel_player, "pitch_scale", 0.62, lift_duration * 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		reel_pitch_swing.tween_property(active_reel_player, "pitch_scale", 1.02, lift_duration * 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "position", target_position, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(active_reel_player):
		active_reel_player.stop()
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


func _play_lift_reel() -> AudioStreamPlayer:
	if fishing_reel_players.is_empty():
		return null
	var player_index := 0
	var pitch_scale := 1.0
	if enemy_mode == MODE_DOUBLE:
		player_index = double_reel_index % fishing_reel_players.size()
		pitch_scale = 0.96 if player_index == 0 else 1.06
	elif enemy_mode == MODE_CASCADE:
		pitch_scale = 0.90
	var reel_player := fishing_reel_players[player_index]
	reel_player.pitch_scale = pitch_scale
	reel_player.play()
	return reel_player


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
	if not active or not player.is_alive():
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
	split_targets = split_targets.filter(func(ball: MergeBall) -> bool:
		return is_instance_valid(ball) and not ball.is_queued_for_deletion()
	)
	var target_count := _target_count()
	if split_targets.size() + pending_split_target_slots >= target_count:
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
	while split_targets.size() + pending_split_target_slots < target_count:
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
	pending_merge_target_slots.clear()
	pending_split_target_slots = 0
	split_cast_resolution_active = false


func _on_merge_registered(_result_level: int, _origin: Vector2, _chain_index: int, source_ids: Array[int], _involved_cursed: bool) -> void:
	var inherited_slot_count := 0
	for target: MergeBall in split_targets.duplicate():
		if is_instance_valid(target) and source_ids.has(target.get_instance_id()):
			inherited_slot_count += 1
			target.set_split_targeted(false)
			split_targets.erase(target)
	pending_merge_target_slots.append(inherited_slot_count)
	pending_split_target_slots += inherited_slot_count
	_update_target_marker()


func _on_merge_completed(merged_ball: MergeBall) -> void:
	var inherited_slot_count := 0
	if not pending_merge_target_slots.is_empty():
		inherited_slot_count = pending_merge_target_slots.pop_front()
	if inherited_slot_count <= 0:
		return
	pending_split_target_slots = maxi(0, pending_split_target_slots - inherited_slot_count)
	if not active or not _is_valid_split_target(merged_ball):
		_ensure_split_targets()
		return
	if split_targets.size() < _target_count() and not split_targets.has(merged_ball):
		merged_ball.set_split_targeted(true, _split_target_color())
		split_targets.append(merged_ball)
	_ensure_split_targets()
	if split_cast_resolution_active:
		_reserve_ready_split_targets()


func _update_target_marker() -> void:
	var marker_color := _split_target_color()
	for target: MergeBall in split_targets:
		if is_instance_valid(target) and not target.merge_locked:
			target.set_split_targeted(true, marker_color)


func _split_target_color() -> Color:
	if split_cast_committed:
		return committed_split_target_color
	if is_instance_valid(enemy) and enemy.character_data != null:
		return enemy.character_data.health_bar_color
	return DEFAULT_TARGET_COLOR


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
	# 분열 예고는 보드 위 연출로 전달하므로 공략용 텍스트 UI는 표시하지 않는다.
	battle.update_gimmick_ui("", "")
	battle.right_status_effects.set_effect(SplitCountdownEffect, turns_remaining)
	battle.show_player_damage_preview(_predicted_split_damage())


func _predicted_split_damage() -> int:
	var successful_damage := _split_damage()
	if _target_count() > 1:
		successful_damage += _partial_split_bonus_damage()
	return maxi(_incomplete_split_damage(), successful_damage)


func _on_cleanup() -> void:
	split_cast_sequence_id += 1
	split_cast_committed = false
	deferred_enemy_configuration = false
	committed_split_target_color = DEFAULT_TARGET_COLOR
	for reel_player in fishing_reel_players:
		if is_instance_valid(reel_player):
			reel_player.stop()
	battle.right_status_effects.remove_effect(SplitCountdownEffect.effect_id)
	battle.clear_player_damage_preview()
	if is_instance_valid(enemy):
		enemy.clear_visual_override()
	_restore_lifted_target()
	_release_suspended_cascade_balls()
	_release_split_target_reservations()
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
