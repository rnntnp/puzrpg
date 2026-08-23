class_name LegacyTestGimmickHandler
extends Node

const TestGimmickDataClass = preload("res://scripts/test_gimmick_data.gd")

var battle: Battle
var enemy: Fighter
var player: Fighter
var merge_game: MergeGame
var data: TestGimmickData
var active := false
var busy := false
var remaining_turns := 0
var duration_remaining := 0
var next_is_special := true
var sequence_index := 0
var direction_sign := 1
var board_step := 0
var active_gravity := false
var gravity_center := Vector2.ZERO
var active_danger := false
var danger_rect := Rect2()
var active_portals := false
var portal_entrance := Vector2.ZERO
var portal_exit := Vector2.ZERO
var rocks: Array[GimmickObject] = []
var falling_rocks: Array[GimmickObject] = []
var rock_quiet_time: Dictionary = {}
var life_bubble: GimmickObject
var weakness_stage := 2
var debug_special_execution_count := 0
var flood_active := false
var flood_surface_y := 0.0
var flood_count := 0
var submerged_damp: Dictionary = {}
var curse_target: MergeBall
var rune_pattern: Array[int] = []
var rune_progress := 0
var rune_turns_left := 0
var rune_cooldown := 0
var auxiliary_attack_turns := 0
var skip_next_attack := false
var trapdoor_section := -1
var bumper: GimmickObject
var weak_zone_section := 0
var weak_zone_move_turns := 0
var echo_current_markers: Array[Vector2] = []
var echo_pending_markers: Array[Vector2] = []
var rewind_records: Dictionary = {}
var mirror_active := false
var active_tweens: Array[Tween] = []
var targeting_mode := 0
var targeting_criterion := 0
var targeting_section := -1
var stance_mode := 0
var stance_side := 0
var stance_left_merges := 0
var stance_right_merges := 0
var stance_damage_records: Array[Dictionary] = []
var filter_mode := 0
var filter_platform_y := 0.0
var filter_left_pass := 2
var filter_right_pass := 2
var filter_swapped := false
var filter_change_turns := 0
var filter_platforms: Array[StaticBody2D] = []
var filter_platform_pass_stages: Array[int] = []
var filter_ball_pass_state: Dictionary = {}
var split_targets: Array[MergeBall] = []
var split_target_merge_pending := false


func configure(
	battle_node: Battle,
	enemy_fighter: Fighter,
	player_fighter: Fighter,
	game: MergeGame,
	gimmick_data: TestGimmickData
) -> void:
	cleanup()
	battle = battle_node
	enemy = enemy_fighter
	player = player_fighter
	merge_game = game
	data = gimmick_data
	active = data != null
	if not active:
		return
	remaining_turns = data.action_interval
	next_is_special = true
	sequence_index = 0
	direction_sign = 1
	board_step = 0
	weakness_stage = data.initial_stage
	debug_special_execution_count = 0
	flood_count = 0
	auxiliary_attack_turns = data.normal_attack_interval
	weak_zone_move_turns = data.action_interval
	targeting_mode = 0
	targeting_criterion = 0
	targeting_section = -1
	stance_mode = 0
	stance_side = 0
	stance_left_merges = 0
	stance_right_merges = 0
	stance_damage_records.clear()
	filter_mode = 0
	filter_platform_y = 0.0
	filter_left_pass = 2
	filter_right_pass = 2
	filter_swapped = false
	filter_change_turns = 0
	filter_platforms.clear()
	filter_platform_pass_stages.clear()
	filter_ball_pass_state.clear()
	_clear_split_targets()
	if not merge_game.merge_completed.is_connected(_on_merge_completed):
		merge_game.merge_completed.connect(_on_merge_completed)
	if not merge_game.merge_registered.is_connected(_on_merge_registered):
		merge_game.merge_registered.connect(_on_merge_registered)
	if not merge_game.player_ball_landed.is_connected(_on_player_ball_landed):
		merge_game.player_ball_landed.connect(_on_player_ball_landed)
	match data.kind:
		TestGimmickData.Kind.PORTAL:
			_set_portals(0)
		TestGimmickData.Kind.LIFE_BUBBLE:
			_spawn_life_bubble()
		TestGimmickData.Kind.WEAKNESS:
			_update_weakness_detail()
		TestGimmickData.Kind.MERGE_SEQUENCE:
			_activate_rune()
		TestGimmickData.Kind.WEAK_ZONE:
			_activate_weak_zone(0)
		TestGimmickData.Kind.BOARD_STATE_TARGETING:
			_configure_board_targeting()
		TestGimmickData.Kind.ENEMY_STANCE:
			_configure_enemy_stance()
		TestGimmickData.Kind.STAGE_FILTER_BOARD:
			_configure_stage_filter()
	_update_action_ui()
	_log("READY", "hp=%d interval=%d" % [data.monster_health, data.action_interval])


func on_turn_completed() -> void:
	if not active or busy or enemy == null or not enemy.is_alive() or not player.is_alive():
		return
	if active_danger:
		_apply_danger_turn_tick()
	if data.kind == TestGimmickData.Kind.MERGE_SEQUENCE:
		_run_rune_turn()
		return
	if data.kind == TestGimmickData.Kind.WEAK_ZONE:
		_run_weak_zone_turn()
		return
	if data.kind == TestGimmickData.Kind.ENEMY_STANCE:
		_finish_stance_turn()
		if stance_mode == 0:
			_update_action_ui()
			return
		remaining_turns = maxi(0, remaining_turns - 1)
		if remaining_turns > 0:
			_update_action_ui()
			return
		await _execute_special()
		return
	if data.kind == TestGimmickData.Kind.STAGE_FILTER_BOARD:
		_run_stage_filter_turn()
		return
	if data.kind == TestGimmickData.Kind.SPLIT and next_is_special:
		_ensure_split_targets()
	if data.kind == TestGimmickData.Kind.MERGE_ECHO:
		await _advance_echo_turn()
	if data.kind == TestGimmickData.Kind.MERGE_CURSE and next_is_special and remaining_turns == 2 and not is_instance_valid(curse_target):
		_preview_curse_target()
	if data.kind == TestGimmickData.Kind.BOARD_STATE_TARGETING:
		_update_board_target()
	if duration_remaining > 0:
		duration_remaining -= 1
		if data.kind == TestGimmickData.Kind.REWIND:
			_update_rewind_labels(duration_remaining)
		if duration_remaining <= 0:
			await _end_duration_effect()
		else:
			_update_action_ui()
		return
	remaining_turns = maxi(0, remaining_turns - 1)
	if remaining_turns > 0:
		_update_action_ui()
		return
	if next_is_special:
		await _execute_special()
	else:
		_execute_normal_attack()


func modify_player_damage(damage: int, merge_result_level_index: int, combo_count := 1, merge_origin := Vector2.ZERO) -> int:
	if not active:
		return damage
	var multiplier := 1.0
	var reason := ""
	if data.kind == TestGimmickData.Kind.WEAKNESS:
		var result_stage := merge_result_level_index + 1
		multiplier = 2.0 if result_stage == weakness_stage else 0.5
		reason = "stage=%d weakness=%d" % [result_stage, weakness_stage]
	elif data.kind == TestGimmickData.Kind.COMBO_BARRIER and duration_remaining > 0:
		if combo_count <= 1:
			multiplier = data.first_chain_multiplier
		elif combo_count == 2:
			multiplier = data.second_chain_multiplier
		else:
			multiplier = data.later_chain_multiplier
		reason = "chain=%d" % combo_count
	elif data.kind == TestGimmickData.Kind.WEAK_ZONE:
		var local_origin := merge_game.to_local(merge_origin)
		multiplier = data.weak_zone_inside_multiplier if danger_rect.has_point(local_origin) else data.weak_zone_outside_multiplier
		reason = "inside=%s" % str(danger_rect.has_point(local_origin))
	elif data.kind == TestGimmickData.Kind.ENEMY_STANCE and stance_mode in [0, 2]:
		var local_origin := merge_game.to_local(merge_origin)
		var record_index := -1
		var nearest_distance := INF
		for index in stance_damage_records.size():
			var record_origin: Vector2 = stance_damage_records[index].get("origin", Vector2.ZERO)
			var distance := record_origin.distance_squared_to(local_origin)
			if distance < nearest_distance:
				nearest_distance = distance
				record_index = index
		if record_index >= 0:
			var record: Dictionary = stance_damage_records[record_index]
			stance_damage_records.remove_at(record_index)
			multiplier = float(record.get("multiplier", 1.0))
			reason = "drop_stance=%s merge_side=%s" % [record.get("stance", "LEFT"), record.get("side", "LEFT")]
		else:
			return damage
	else:
		return damage
	var modified := maxi(1, roundi(float(damage) * multiplier))
	_log("DAMAGE MODIFIER", "%s multiplier=%.2f damage=%d->%d" % [reason, multiplier, damage, modified])
	return modified


func cleanup() -> void:
	active = false
	busy = false
	active_gravity = false
	active_danger = false
	active_portals = false
	flood_active = false
	mirror_active = false
	duration_remaining = 0
	for tween in active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	active_tweens.clear()
	_restore_submerged_balls()
	_clear_curse()
	_clear_rewind_records()
	echo_current_markers.clear()
	echo_pending_markers.clear()
	stance_damage_records.clear()
	stance_left_merges = 0
	stance_right_merges = 0
	filter_ball_pass_state.clear()
	filter_platforms.clear()
	filter_platform_pass_stages.clear()
	if is_instance_valid(bumper):
		bumper.queue_free()
	bumper = null
	rocks.clear()
	falling_rocks.clear()
	rock_quiet_time.clear()
	life_bubble = null
	if is_instance_valid(merge_game):
		merge_game.reset_gimmick_state()
	if is_instance_valid(battle):
		battle.update_gimmick_ui("", "")


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(merge_game):
		return
	if active_gravity:
		_apply_gravity_force()
	if flood_active:
		_apply_flood_physics()
	if active_portals:
		_process_portals()
	if mirror_active:
		_update_mirror_overlay()
	if data.kind == TestGimmickData.Kind.STAGE_FILTER_BOARD:
		_update_stage_filter_collisions()
	_process_falling_rocks(delta)


func _execute_special() -> void:
	busy = true
	debug_special_execution_count += 1
	merge_game.set_input_enabled(false)
	battle.status_label.text = "%s 발동!" % data.display_name
	battle.status_label.modulate = Color("#ffd166")
	var succeeded := true
	match data.kind:
		TestGimmickData.Kind.ENLARGE:
			succeeded = await _enlarge_ball()
		TestGimmickData.Kind.HEAVY:
			succeeded = _make_ball_heavy()
		TestGimmickData.Kind.SPLIT:
			succeeded = _split_ball()
		TestGimmickData.Kind.DUPLICATE:
			succeeded = _duplicate_ball()
		TestGimmickData.Kind.COMPRESS:
			succeeded = await _compress_board()
		TestGimmickData.Kind.RAISE_FLOOR:
			succeeded = await _raise_floor()
		TestGimmickData.Kind.TILT:
			await _tilt_board()
		TestGimmickData.Kind.SHOCKWAVE_VERTICAL:
			_shockwave(Vector2.UP)
		TestGimmickData.Kind.SHOCKWAVE_HORIZONTAL:
			_shockwave(Vector2(direction_sign, 0.0))
			direction_sign *= -1
		TestGimmickData.Kind.ROCK_WALL:
			succeeded = await _spawn_rock_wall()
		TestGimmickData.Kind.ROCK_FALL:
			succeeded = _drop_rock()
		TestGimmickData.Kind.PORTAL:
			sequence_index = (sequence_index + 1) % 2
			_set_portals(sequence_index)
		TestGimmickData.Kind.GRAVITY_FIELD:
			_activate_gravity_field()
		TestGimmickData.Kind.DANGER_ZONE:
			_activate_danger_zone()
		TestGimmickData.Kind.QUEUE_SHUFFLE:
			_shuffle_queue()
		TestGimmickData.Kind.SEAL_STAGE:
			_activate_stage_seal()
		TestGimmickData.Kind.WEAKNESS:
			_rotate_weakness()
		TestGimmickData.Kind.DROP_RESTRICTION:
			_activate_drop_restriction()
		TestGimmickData.Kind.SWAP:
			succeeded = await _swap_balls()
		TestGimmickData.Kind.LIFE_BUBBLE:
			succeeded = _attack_life_bubble()
		TestGimmickData.Kind.FLOOD:
			await _start_flood()
		TestGimmickData.Kind.MERGE_CURSE:
			succeeded = _apply_merge_curse()
		TestGimmickData.Kind.COMBO_BARRIER:
			_log("COMBO BARRIER", "active")
		TestGimmickData.Kind.TRAPDOOR:
			await _lower_trapdoor()
		TestGimmickData.Kind.BUMPER:
			_spawn_bumper()
		TestGimmickData.Kind.MERGE_ECHO:
			echo_current_markers.clear()
			echo_pending_markers.clear()
		TestGimmickData.Kind.REWIND:
			succeeded = _mark_rewind_targets()
		TestGimmickData.Kind.MIRROR_DROP:
			mirror_active = true
			_update_mirror_overlay()
		TestGimmickData.Kind.BOARD_STATE_TARGETING:
			succeeded = await _execute_board_targeting_attack()
		TestGimmickData.Kind.ENEMY_STANCE:
			succeeded = await _execute_stance_attack()
	if not succeeded:
		_log("FALLBACK", "valid target unavailable")
		enemy.attack_with_damage(player, data.normal_attack_damage)
	if data.kind in [TestGimmickData.Kind.BOARD_STATE_TARGETING, TestGimmickData.Kind.ENEMY_STANCE]:
		next_is_special = true
		remaining_turns = data.action_interval
	elif data.kind == TestGimmickData.Kind.SPLIT:
		next_is_special = true
		remaining_turns = data.action_interval
	elif _uses_duration() and succeeded:
		duration_remaining = maxi(1, data.duration_turns)
	else:
		_schedule_normal_attack()
	await get_tree().create_timer(0.12, true, false, true).timeout
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	busy = false
	_update_action_ui()


func _uses_duration() -> bool:
	return data.kind in [
		TestGimmickData.Kind.TILT,
		TestGimmickData.Kind.GRAVITY_FIELD,
		TestGimmickData.Kind.DANGER_ZONE,
		TestGimmickData.Kind.SEAL_STAGE,
		TestGimmickData.Kind.DROP_RESTRICTION,
		TestGimmickData.Kind.FLOOD,
		TestGimmickData.Kind.MERGE_CURSE,
		TestGimmickData.Kind.COMBO_BARRIER,
		TestGimmickData.Kind.TRAPDOOR,
		TestGimmickData.Kind.BUMPER,
		TestGimmickData.Kind.MERGE_ECHO,
		TestGimmickData.Kind.REWIND,
		TestGimmickData.Kind.MIRROR_DROP,
	]


func _end_duration_effect() -> void:
	busy = true
	merge_game.set_input_enabled(false)
	match data.kind:
		TestGimmickData.Kind.TILT:
			await merge_game.animate_board_tilt(0.0, data.animation_duration)
		TestGimmickData.Kind.GRAVITY_FIELD:
			active_gravity = false
			merge_game.gimmick_overlay.clear_gravity()
		TestGimmickData.Kind.DANGER_ZONE:
			active_danger = false
			danger_rect = Rect2()
			merge_game.gimmick_overlay.clear_zone()
			for ball in _valid_balls():
				ball.set_hazard_turns(0)
		TestGimmickData.Kind.SEAL_STAGE:
			merge_game.set_sealed_stage(0)
		TestGimmickData.Kind.DROP_RESTRICTION:
			merge_game.clear_blocked_drop_zone()
			merge_game.gimmick_overlay.clear_zone()
		TestGimmickData.Kind.FLOOD:
			await _end_flood()
		TestGimmickData.Kind.MERGE_CURSE:
			_clear_curse()
		TestGimmickData.Kind.COMBO_BARRIER:
			pass
		TestGimmickData.Kind.TRAPDOOR:
			await merge_game.animate_trapdoor(trapdoor_section, data.trapdoor_depth_ratio, data.animation_duration, false)
			merge_game.set_trapdoor_enabled(false)
			merge_game.gimmick_overlay.clear_zone()
			trapdoor_section = -1
		TestGimmickData.Kind.BUMPER:
			_remove_bumper()
		TestGimmickData.Kind.MERGE_ECHO:
			# 대기 중 잔향은 다음 투하에서 한 번 더 발동한 뒤 제거된다.
			if echo_pending_markers.is_empty():
				merge_game.gimmick_overlay.show_echo_markers([])
		TestGimmickData.Kind.REWIND:
			await _rewind_marked_balls()
		TestGimmickData.Kind.MIRROR_DROP:
			mirror_active = false
			merge_game.gimmick_overlay.clear_mirror()
	_schedule_normal_attack()
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
	busy = false
	_update_action_ui()


func _execute_normal_attack() -> void:
	enemy.attack_with_damage(player, data.normal_attack_damage)
	next_is_special = true
	remaining_turns = data.action_interval
	_log("NORMAL ATTACK", "damage=%d" % data.normal_attack_damage)
	_update_action_ui()


func _schedule_normal_attack() -> void:
	next_is_special = false
	remaining_turns = data.normal_attack_interval


func _start_flood() -> void:
	flood_count += 1
	var ratio := data.initial_flood_ratio if flood_count == 1 else data.maximum_flood_ratio
	ratio = minf(ratio, data.maximum_flood_ratio)
	var bounds := merge_game.get_base_board_bounds()
	flood_surface_y = bounds.end.y
	flood_active = true
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	merge_game.gimmick_overlay.show_zone(Rect2(Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.size.x, 0.0)), Color(0.12, 0.55, 0.95, 0.28), "수면")
	var target_y := bounds.end.y - bounds.size.y * ratio
	var tween := _create_gimmick_tween()
	tween.tween_method(func(value: float) -> void:
		flood_surface_y = value
		merge_game.gimmick_overlay.show_zone(Rect2(Vector2(bounds.position.x, value), Vector2(bounds.size.x, bounds.end.y - value)), Color(0.12, 0.55, 0.95, 0.28), "수면")
	, bounds.end.y, target_y, data.animation_duration)
	await tween.finished
	_log("FLOOD", "height_ratio=%.2f" % ratio)


func _end_flood() -> void:
	var bounds := merge_game.get_base_board_bounds()
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	var tween := _create_gimmick_tween()
	tween.tween_method(func(value: float) -> void:
		flood_surface_y = value
		merge_game.gimmick_overlay.show_zone(Rect2(Vector2(bounds.position.x, value), Vector2(bounds.size.x, bounds.end.y - value)), Color(0.12, 0.55, 0.95, 0.28), "수면")
	, flood_surface_y, bounds.end.y, data.animation_duration)
	await tween.finished
	flood_active = false
	merge_game.gimmick_overlay.clear_zone()
	_restore_submerged_balls()


func _apply_flood_physics() -> void:
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	for ball in _valid_balls():
		var submerged := ball.position.y >= flood_surface_y
		var id := ball.get_instance_id()
		if submerged:
			if not submerged_damp.has(id):
				submerged_damp[id] = ball.linear_damp
			ball.linear_damp = data.submerged_linear_damp
			ball.set_submerged(true)
			ball.apply_central_force(Vector2.UP * gravity * ball.gravity_scale * ball.mass * data.buoyancy_ratio)
		elif submerged_damp.has(id):
			ball.linear_damp = float(submerged_damp[id])
			submerged_damp.erase(id)
			ball.set_submerged(false)


func _restore_submerged_balls() -> void:
	if not is_instance_valid(merge_game):
		submerged_damp.clear()
		return
	for ball in _valid_balls():
		var id := ball.get_instance_id()
		if submerged_damp.has(id):
			ball.linear_damp = float(submerged_damp[id])
		ball.set_submerged(false)
	submerged_damp.clear()


func _preview_curse_target() -> void:
	curse_target = _topmost_candidate(data.minimum_ball_stage, data.maximum_ball_stage)
	if is_instance_valid(curse_target):
		curse_target.set_merge_curse(false, true)
		_log("CURSE TARGET", _ball_log(curse_target))


func _apply_merge_curse() -> bool:
	if not is_instance_valid(curse_target):
		return false
	curse_target.set_merge_curse(true)
	_log("CURSE", _ball_log(curse_target))
	return true


func _clear_curse() -> void:
	if is_instance_valid(curse_target):
		curse_target.set_merge_curse(false)
	curse_target = null


func _activate_rune() -> void:
	var patterns: Array = [[2, 3, 4], [3, 2, 4]]
	rune_pattern.clear()
	for stage in patterns[sequence_index % patterns.size()]:
		rune_pattern.append(int(stage))
	sequence_index += 1
	rune_progress = 0
	rune_turns_left = data.rune_turn_limit
	rune_cooldown = 0
	_log("RUNE", "pattern=%s" % _rune_text())


func _run_rune_turn() -> void:
	auxiliary_attack_turns -= 1
	if auxiliary_attack_turns <= 0:
		if skip_next_attack:
			skip_next_attack = false
			_log("RUNE", "normal attack skipped")
		else:
			enemy.attack_with_damage(player, data.normal_attack_damage)
		auxiliary_attack_turns = data.normal_attack_interval
	if rune_turns_left > 0:
		rune_turns_left -= 1
		if rune_turns_left <= 0:
			rune_cooldown = data.rune_restart_delay
			rune_progress = 0
	elif rune_cooldown > 0:
		rune_cooldown -= 1
		if rune_cooldown <= 0:
			_activate_rune()
	_update_action_ui()


func _rune_text() -> String:
	var parts: Array[String] = []
	for index in rune_pattern.size():
		parts.append(("✓%d" if index < rune_progress else "%d") % rune_pattern[index])
	return " → ".join(parts)


func _activate_weak_zone(section: int) -> void:
	weak_zone_section = section
	var bounds := merge_game.get_base_board_bounds()
	danger_rect = _section_rect(section)
	danger_rect.position.y = merge_game.danger_line_y
	danger_rect.size.y = maxf(0.0, bounds.end.y - merge_game.danger_line_y)
	merge_game.gimmick_overlay.show_zone(danger_rect, Color(0.2, 0.95, 0.55, 0.2), "약점 ×2.5")


func _run_weak_zone_turn() -> void:
	weak_zone_move_turns -= 1
	auxiliary_attack_turns -= 1
	if weak_zone_move_turns <= 0:
		var order: Array[int] = [0, 2, 1]
		var current := order.find(weak_zone_section)
		_activate_weak_zone(order[(current + 1) % order.size()])
		weak_zone_move_turns = data.action_interval
	if auxiliary_attack_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		auxiliary_attack_turns = data.normal_attack_interval
	_update_action_ui()


func _lower_trapdoor() -> void:
	var order: Array[int] = [0, 2, 1]
	trapdoor_section = order[sequence_index % order.size()]
	sequence_index += 1
	merge_game.set_trapdoor_enabled(true)
	merge_game.gimmick_overlay.show_zone(_section_rect(trapdoor_section), Color(0.95, 0.55, 0.15, 0.16), "TRAPDOOR ↓")
	await merge_game.animate_trapdoor(trapdoor_section, data.trapdoor_depth_ratio, data.animation_duration, true)
	_log("TRAPDOOR", "section=%d" % trapdoor_section)


func _spawn_bumper() -> void:
	_remove_bumper()
	var normalized_positions := [Vector2(0.5, 0.7), Vector2(0.25, 0.5), Vector2(0.75, 0.5)]
	var normalized: Vector2 = normalized_positions[sequence_index % normalized_positions.size()]
	sequence_index += 1
	var bounds := merge_game.get_base_board_bounds()
	bumper = merge_game.spawn_gimmick_object()
	bumper.configure_bumper(data.bumper_radius)
	bumper.position = bounds.position + bounds.size * normalized
	bumper.body_entered.connect(_on_bumper_body_entered)


func _on_bumper_body_entered(body: Node) -> void:
	if not body is MergeBall or not is_instance_valid(bumper):
		return
	var ball := body as MergeBall
	var now := Time.get_ticks_msec()
	if now < ball.bumper_cooldown_until_msec:
		return
	var direction := (ball.position - bumper.position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	ball.apply_central_impulse(direction * data.bumper_impulse_speed * ball.mass)
	if ball.linear_velocity.length() > data.bumper_max_speed:
		ball.linear_velocity = ball.linear_velocity.normalized() * data.bumper_max_speed
	ball.bumper_cooldown_until_msec = now + roundi(data.bumper_cooldown * 1000.0)


func _remove_bumper() -> void:
	if not is_instance_valid(bumper):
		bumper = null
		return
	bumper.collision_layer = 0
	bumper.collision_mask = 0
	bumper.queue_free()
	bumper = null


func _advance_echo_turn() -> void:
	if not echo_pending_markers.is_empty():
		var firing: Array[Vector2] = echo_pending_markers.duplicate()
		echo_pending_markers.clear()
		for marker in firing:
			if not active:
				return
			_apply_radial_impulse(marker, data.effect_radius, data.impulse_speed)
			await get_tree().create_timer(data.echo_interval, true, false, true).timeout
	if duration_remaining > 0:
		echo_pending_markers = echo_current_markers.duplicate()
	else:
		echo_pending_markers.clear()
	echo_current_markers.clear()
	merge_game.gimmick_overlay.show_echo_markers(echo_pending_markers)


func _apply_radial_impulse(origin: Vector2, radius: float, speed: float) -> void:
	for ball in _valid_balls():
		var offset := ball.position - origin
		if offset.length() <= 0.01 or offset.length() > radius:
			continue
		var falloff := 1.0 - offset.length() / radius
		ball.apply_central_impulse(offset.normalized() * speed * falloff * ball.mass)


func _mark_rewind_targets() -> bool:
	_clear_rewind_records()
	var bounds := merge_game.get_base_board_bounds()
	var candidates := _valid_balls().filter(func(ball: MergeBall) -> bool:
		return ball.position.y <= bounds.position.y + bounds.size.y * 0.5 and (ball.sleeping or ball.linear_velocity.length() < 8.0)
	)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.y < b.position.y)
	var selected_stages: Array[int] = []
	for ball in candidates:
		if ball.merge_level in selected_stages:
			continue
		selected_stages.append(ball.merge_level)
		rewind_records[ball.get_instance_id()] = {"ball": ball, "position": ball.position, "rotation": ball.rotation}
		ball.set_rewind_turns(data.duration_turns)
		if rewind_records.size() >= data.rewind_target_count:
			break
	if rewind_records.size() < data.rewind_target_count:
		for ball in candidates:
			if rewind_records.has(ball.get_instance_id()):
				continue
			rewind_records[ball.get_instance_id()] = {"ball": ball, "position": ball.position, "rotation": ball.rotation}
			ball.set_rewind_turns(data.duration_turns)
			if rewind_records.size() >= data.rewind_target_count:
				break
	return not rewind_records.is_empty()


func _clear_rewind_records() -> void:
	for record in rewind_records.values():
		var ball := record.get("ball") as MergeBall
		if is_instance_valid(ball):
			ball.set_rewind_turns(0)
	rewind_records.clear()


func _rewind_marked_balls() -> void:
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	var bounds := merge_game.get_base_board_bounds()
	for record in rewind_records.values():
		var ball := record.get("ball") as MergeBall
		if not is_instance_valid(ball) or ball.merge_locked:
			continue
		ball.collision_layer = 0
		ball.collision_mask = 0
		ball.freeze = true
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		var desired: Vector2 = record.get("position")
		var safe := desired
		var step := maxf(8.0, ball.get_radius() * 0.35)
		var searched := 0.0
		while not merge_game.is_ball_position_safe(ball, safe) and searched <= bounds.size.y * data.rewind_search_ratio:
			safe.y -= step
			searched += step
		if not merge_game.is_ball_position_safe(ball, safe):
			safe = Vector2(desired.x, bounds.position.y + ball.get_radius() + 8.0)
		var tween := _create_gimmick_tween().set_parallel(true)
		tween.tween_property(ball, "position", safe, data.animation_duration)
		tween.tween_property(ball, "rotation", float(record.get("rotation")), data.animation_duration)
		await tween.finished
		if is_instance_valid(ball):
			ball.collision_layer = 1
			ball.collision_mask = 1
			ball.freeze = false
			ball.set_rewind_turns(0)
	rewind_records.clear()


func _update_mirror_overlay() -> void:
	var bounds := merge_game.get_board_inner_bounds()
	var center_x := bounds.get_center().x
	var ghost_x := center_x * 2.0 - merge_game.aim_x
	ghost_x = clampf(ghost_x, bounds.position.x + 20.0, bounds.end.x - 20.0)
	merge_game.gimmick_overlay.show_mirror(center_x, ghost_x, merge_game.drop_position_y)


func _on_player_ball_landed(level: int, drop_x: float) -> void:
	if not active or not mirror_active or not enemy.is_alive():
		return
	_spawn_mirror_ball(level, drop_x)


func _spawn_mirror_ball(level: int, drop_x: float) -> void:
	await get_tree().create_timer(data.mirror_spawn_delay, true, false, true).timeout
	if not active or not mirror_active or not enemy.is_alive():
		return
	var bounds := merge_game.get_board_inner_bounds()
	var mirrored_x := bounds.get_center().x * 2.0 - drop_x
	var level_index := mini(level, data.mirror_maximum_stage - 1)
	var radius := 26.0
	mirrored_x = clampf(mirrored_x, bounds.position.x + radius, bounds.end.x - radius)
	merge_game.spawn_gimmick_ball(level_index, Vector2(mirrored_x, merge_game.drop_position_y))


func _configure_board_targeting() -> void:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index < data.targeting_enemy_modes.size():
		targeting_mode = clampi(data.targeting_enemy_modes[enemy_index], 0, 2)
	else:
		targeting_mode = 2
	targeting_criterion = 1 if targeting_mode == 1 else 0
	targeting_section = -1
	_update_board_target()


func _update_board_target() -> void:
	var metrics: Array[float] = [0.0, 0.0, 0.0]
	var bounds := merge_game.get_base_board_bounds()
	for ball in _valid_balls():
		var section := _board_section_for_x(ball.position.x, bounds)
		if targeting_criterion == 0:
			var stack_height := bounds.end.y - (ball.position.y - ball.get_radius())
			metrics[section] = maxf(metrics[section], stack_height)
		else:
			metrics[section] += 1.0
	var best_value: float = maxf(metrics[0], maxf(metrics[1], metrics[2]))
	var leaders: Array[int] = []
	for index in 3:
		if is_equal_approx(metrics[index], best_value):
			leaders.append(index)
	var previous := targeting_section
	if targeting_section not in leaders:
		targeting_section = leaders.front() if not leaders.is_empty() else 0
	merge_game.gimmick_overlay.show_board_targeting(bounds, targeting_section)
	if previous >= 0 and previous != targeting_section:
		_log("TARGET CHANGED", "%s -> %s" % [_section_name(previous), _section_name(targeting_section)])
	_update_action_ui()


func _board_section_for_x(x_position: float, bounds: Rect2) -> int:
	var normalized := clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _execute_board_targeting_attack() -> bool:
	_update_board_target()
	var bounds := merge_game.get_base_board_bounds()
	var candidates: Array[MergeBall] = []
	for ball in _valid_balls():
		if _board_section_for_x(ball.position.x, bounds) == targeting_section:
			candidates.append(ball)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else a.position.y < b.position.y
	)
	if candidates.is_empty():
		_log("TARGET ATTACK", "%s empty" % _section_name(targeting_section))
	else:
		var target: MergeBall = candidates.front() as MergeBall
		var old_stage: int = target.merge_level + 1
		target.modulate = Color("#ff6b6b")
		var tween := _create_gimmick_tween()
		tween.tween_property(target, "modulate", Color.WHITE, 0.2)
		await tween.finished
		if is_instance_valid(target) and not target.merge_locked:
			var new_level: int = target.merge_level - data.targeting_stage_loss
			if new_level < 0:
				merge_game.remove_gimmick_ball(target)
			else:
				merge_game.replace_ball_stage(target, new_level)
			_log("TARGET ATTACK", "%s stage=%d->%d" % [_section_name(targeting_section), old_stage, maxi(0, new_level + 1)])
	if targeting_mode == 2:
		targeting_criterion = 1 - targeting_criterion
		_update_board_target()
	return true


func _configure_enemy_stance() -> void:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index < data.stance_enemy_modes.size():
		stance_mode = clampi(data.stance_enemy_modes[enemy_index], 0, 2)
	else:
		stance_mode = 2
	stance_side = 0
	stance_left_merges = 0
	stance_right_merges = 0
	stance_damage_records.clear()
	remaining_turns = data.action_interval
	_update_stance_overlay()


func _finish_stance_turn() -> void:
	var previous := stance_side
	if stance_left_merges > stance_right_merges:
		stance_side = 0
	elif stance_right_merges > stance_left_merges:
		stance_side = 1
	stance_left_merges = 0
	stance_right_merges = 0
	_update_stance_overlay()
	if previous != stance_side:
		battle.status_label.text = "STANCE CHANGED: %s" % _stance_side_name(stance_side)
		battle.status_label.modulate = Color("#ffd166")
		_log("STANCE CHANGED", "%s -> %s" % [_stance_side_name(previous), _stance_side_name(stance_side)])


func _update_stance_overlay() -> void:
	if not is_instance_valid(merge_game):
		return
	merge_game.gimmick_overlay.show_enemy_stance(
		merge_game.get_base_board_bounds(),
		stance_side,
		stance_mode in [0, 2],
		stance_mode in [1, 2]
	)


func _stance_side_for_x(x_position: float, bounds: Rect2) -> int:
	return 0 if x_position < bounds.get_center().x else 1


func _stance_side_name(side: int) -> String:
	return "LEFT" if side == 0 else "RIGHT"


func _execute_stance_attack() -> bool:
	var bounds := merge_game.get_base_board_bounds()
	var candidates: Array[MergeBall] = []
	for ball in _valid_balls():
		if _stance_side_for_x(ball.position.x, bounds) == stance_side:
			candidates.append(ball)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else a.position.y < b.position.y
	)
	if candidates.is_empty():
		_log("STANCE ATTACK", "%s empty" % _stance_side_name(stance_side))
		return true
	var target: MergeBall = candidates.front() as MergeBall
	var old_stage: int = target.merge_level + 1
	target.modulate = Color("#ff6b6b")
	var tween := _create_gimmick_tween()
	tween.tween_property(target, "modulate", Color.WHITE, 0.2)
	await tween.finished
	if is_instance_valid(target) and not target.merge_locked:
		var new_level: int = target.merge_level - data.stance_stage_loss
		if new_level < 0:
			merge_game.remove_gimmick_ball(target)
		else:
			merge_game.replace_ball_stage(target, new_level)
		_log("STANCE ATTACK", "%s stage=%d->%d" % [_stance_side_name(stance_side), old_stage, maxi(0, new_level + 1)])
	return true


func _configure_stage_filter() -> void:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index < data.filter_enemy_modes.size():
		filter_mode = clampi(data.filter_enemy_modes[enemy_index], 0, 2)
	else:
		filter_mode = 2
	filter_swapped = false
	filter_change_turns = data.filter_swap_interval if filter_mode == 2 else -1
	remaining_turns = data.normal_attack_interval
	var bounds := merge_game.get_base_board_bounds()
	filter_platform_y = bounds.position.y + bounds.size.y * data.filter_height_ratio
	var thickness := data.filter_platform_thickness
	if filter_mode == 0:
		var rect := Rect2(Vector2(bounds.position.x, filter_platform_y - thickness * 0.5), Vector2(bounds.size.x, thickness))
		filter_platforms.append(merge_game.spawn_one_way_platform(rect, data.filter_one_way_margin))
	else:
		var half_width := bounds.size.x * 0.5
		var left_rect := Rect2(Vector2(bounds.position.x, filter_platform_y - thickness * 0.5), Vector2(half_width, thickness))
		var right_rect := Rect2(Vector2(bounds.position.x + half_width, filter_platform_y - thickness * 0.5), Vector2(half_width, thickness))
		filter_platforms.append(merge_game.spawn_one_way_platform(left_rect, data.filter_one_way_margin))
		filter_platforms.append(merge_game.spawn_one_way_platform(right_rect, data.filter_one_way_margin))
	_apply_stage_filter_state()


func _apply_stage_filter_state() -> void:
	if filter_mode == 0:
		filter_left_pass = data.filter_basic_pass_stage
		filter_right_pass = filter_left_pass
		filter_platform_pass_stages.assign([filter_left_pass])
	else:
		filter_left_pass = data.filter_right_pass_stage if filter_swapped else data.filter_left_pass_stage
		filter_right_pass = data.filter_left_pass_stage if filter_swapped else data.filter_right_pass_stage
		filter_platform_pass_stages.assign([filter_left_pass, filter_right_pass])
	filter_ball_pass_state.clear()
	_update_stage_filter_collisions()
	_update_stage_filter_overlay()


func _run_stage_filter_turn() -> void:
	if filter_mode == 2:
		filter_change_turns = maxi(0, filter_change_turns - 1)
		if filter_change_turns <= 0:
			filter_swapped = not filter_swapped
			filter_change_turns = data.filter_swap_interval
			_apply_stage_filter_state()
			battle.status_label.text = "FILTER CHANGED"
			battle.status_label.modulate = Color("#ffd166")
			_log("FILTER CHANGED", "left=1~%d right=1~%d" % [filter_left_pass, filter_right_pass])
	remaining_turns = maxi(0, remaining_turns - 1)
	if remaining_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		remaining_turns = data.normal_attack_interval
	_update_stage_filter_overlay()
	_update_action_ui()


func _update_stage_filter_collisions() -> void:
	if filter_platforms.is_empty():
		return
	for ball in _valid_balls():
		for index in filter_platforms.size():
			var platform := filter_platforms[index]
			if not is_instance_valid(platform) or index >= filter_platform_pass_stages.size():
				continue
			var cache_key := Vector2i(ball.get_instance_id(), index)
			var can_pass := ball.merge_level + 1 <= filter_platform_pass_stages[index]
			if filter_ball_pass_state.get(cache_key, null) == can_pass:
				continue
			if can_pass:
				ball.add_collision_exception_with(platform)
			else:
				ball.remove_collision_exception_with(platform)
			filter_ball_pass_state[cache_key] = can_pass


func _update_stage_filter_overlay() -> void:
	if not is_instance_valid(merge_game):
		return
	merge_game.gimmick_overlay.show_stage_filter(
		merge_game.get_base_board_bounds(),
		filter_platform_y,
		filter_left_pass,
		filter_right_pass,
		filter_mode != 0,
		filter_change_turns if filter_mode == 2 else -1
	)


func _section_name(section: int) -> String:
	return ["LEFT", "CENTER", "RIGHT"][clampi(section, 0, 2)]


func _valid_balls(minimum_stage := 1, maximum_stage := 11) -> Array[MergeBall]:
	var result: Array[MergeBall] = []
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		var stage := ball.merge_level + 1
		if ball.merge_locked or ball.is_queued_for_deletion() or stage < minimum_stage or stage > maximum_stage:
			continue
		result.append(ball)
	return result


func _topmost_candidate(minimum_stage: int, maximum_stage: int, exclude_enlarged := false, exclude_heavy := false) -> MergeBall:
	var candidates := _valid_balls(minimum_stage, maximum_stage)
	candidates = candidates.filter(func(ball: MergeBall) -> bool:
		return (not exclude_enlarged or not ball.is_enlarged) and (not exclude_heavy or not ball.is_heavy)
	)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.y < b.position.y)
	return candidates.front() if not candidates.is_empty() else null


func _enlarge_ball() -> bool:
	var enlarged_count := 0
	for ball in _valid_balls():
		if ball.is_enlarged:
			enlarged_count += 1
	if enlarged_count >= data.maximum_targets:
		return false
	var target := _topmost_candidate(data.minimum_ball_stage, data.maximum_ball_stage, true, false)
	if target == null:
		return false
	target.set_enlarged(true, data.size_multiplier, data.animation_duration)
	_log("ENLARGE", _ball_log(target))
	await get_tree().create_timer(data.animation_duration, true, false, true).timeout
	return true


func _make_ball_heavy() -> bool:
	var heavy_count := 0
	for ball in _valid_balls():
		if ball.is_heavy:
			heavy_count += 1
	if heavy_count >= data.maximum_targets:
		return false
	var target := _topmost_candidate(data.minimum_ball_stage, data.maximum_ball_stage, false, true)
	if target == null:
		return false
	target.set_heavy(true, data.mass_multiplier)
	_log("HEAVY", _ball_log(target))
	return true


func _split_ball() -> bool:
	_ensure_split_targets()
	if split_targets.is_empty():
		return false
	var split_succeeded := false
	var targets_to_split: Array[MergeBall] = split_targets.duplicate()
	_clear_split_targets()
	for target in targets_to_split:
		if not is_instance_valid(target) or target.merge_locked:
			continue
		var parent_position: Vector2 = target.position
		var child_level: int = target.merge_level - 1
		merge_game.remove_gimmick_ball(target)
		var first := merge_game.spawn_gimmick_ball(child_level, parent_position + Vector2(-data.spawn_offset.x, data.spawn_offset.y))
		var second := merge_game.spawn_gimmick_ball(child_level, parent_position + Vector2(data.spawn_offset.x, data.spawn_offset.y))
		if is_instance_valid(first) and is_instance_valid(second):
			# 큰 분열 공은 같은 속도 대입만으로는 상대적으로 덜 퍼져 보이므로 크기에 비례해 보정한다.
			var spread_scale := clampf(first.get_radius() / 35.0, 1.0, 2.0)
			first.linear_velocity = Vector2(-absf(data.initial_velocity.x), data.initial_velocity.y) * spread_scale
			second.linear_velocity = Vector2(absf(data.initial_velocity.x), data.initial_velocity.y) * spread_scale
			first.add_collision_exception_with(second)
			second.add_collision_exception_with(first)
			_remove_split_exception(first, second)
			_log("SPLIT", "stage=%d -> %d + %d" % [child_level + 2, child_level + 1, child_level + 1])
			split_succeeded = true
	return split_succeeded


func _ensure_split_targets() -> void:
	if data.kind != TestGimmickData.Kind.SPLIT:
		return
	split_targets = split_targets.filter(func(ball: MergeBall) -> bool: return is_instance_valid(ball) and not ball.merge_locked)
	if not split_targets.is_empty():
		return
	var candidates := _valid_balls(data.minimum_ball_stage, data.maximum_ball_stage)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else a.position.y < b.position.y
	)
	var target_count := mini(1 + battle.current_enemy_index, candidates.size())
	for index in range(target_count):
		var target: MergeBall = candidates[index]
		split_targets.append(target)
		target.set_split_targeted(true)


func _clear_split_targets() -> void:
	for target in split_targets:
		if is_instance_valid(target):
			target.set_split_targeted(false)
	split_targets.clear()
	split_target_merge_pending = false


func _remove_split_exception(first: MergeBall, second: MergeBall) -> void:
	await get_tree().create_timer(0.35, true, false, true).timeout
	if is_instance_valid(first) and is_instance_valid(second):
		first.remove_collision_exception_with(second)
		second.remove_collision_exception_with(first)


func _duplicate_ball() -> bool:
	var target := _topmost_candidate(data.minimum_ball_stage, data.maximum_ball_stage)
	if target == null:
		return false
	var bounds := merge_game.get_board_inner_bounds()
	var spawn_at := Vector2(clampf(target.position.x, bounds.position.x + target.get_radius(), bounds.end.x - target.get_radius()), merge_game.drop_position_y)
	merge_game.spawn_gimmick_ball(target.merge_level, spawn_at)
	_log("DUPLICATE", _ball_log(target))
	return true


func _compress_board() -> bool:
	if board_step >= data.maximum_board_steps:
		return false
	board_step += 1
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	await merge_game.animate_board_compression(data.board_step_ratio, data.animation_duration)
	_log("COMPRESS", "step=%d" % board_step)
	return true


func _raise_floor() -> bool:
	if board_step >= data.maximum_board_steps:
		return false
	board_step += 1
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	await merge_game.animate_floor_rise(data.board_step_ratio, data.animation_duration)
	_log("RAISE FLOOR", "step=%d" % board_step)
	return true


func _tilt_board() -> void:
	var degrees := data.tilt_degrees * float(direction_sign)
	direction_sign *= -1
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	await merge_game.animate_board_tilt(degrees, data.animation_duration)
	_log("TILT", "degrees=%.1f" % degrees)


func _shockwave(direction: Vector2) -> void:
	merge_game.suppress_danger_line(0.5)
	merge_game.apply_velocity_impulse(direction.normalized() * data.impulse_speed)
	_log("SHOCKWAVE", "direction=%s speed=%.1f" % [str(direction), data.impulse_speed])


func _section_rect(index: int) -> Rect2:
	var bounds := merge_game.get_base_board_bounds()
	var width := bounds.size.x / 3.0
	return Rect2(Vector2(bounds.position.x + width * float(index), bounds.position.y), Vector2(width, bounds.size.y))


func _section_center(index: int) -> Vector2:
	return _section_rect(index).get_center()


func _spawn_rock_wall() -> bool:
	if rocks.size() >= data.maximum_targets:
		return false
	var order: Array[int] = [0, 2, 1]
	var section: int = order[sequence_index % order.size()]
	sequence_index += 1
	var bounds := merge_game.get_base_board_bounds()
	var size := Vector2(bounds.size.x * data.obstacle_width_ratio, bounds.size.y * data.obstacle_height_ratio)
	var rock := merge_game.spawn_gimmick_object()
	rock.configure_rock(size, data.obstacle_durability, false)
	rock.position = Vector2(_section_center(section).x, bounds.end.y + size.y * 0.5)
	rocks.append(rock)
	merge_game.suppress_danger_line(data.animation_duration + 0.5)
	var tween := _create_gimmick_tween()
	tween.tween_property(rock, "position:y", bounds.end.y - size.y * 0.5, data.animation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_log("ROCK WALL", "section=%d durability=%d" % [section, data.obstacle_durability])
	return true


func _drop_rock() -> bool:
	if rocks.size() >= data.maximum_targets:
		return false
	var order: Array[int] = [0, 2, 1]
	var section: int = order[sequence_index % order.size()]
	sequence_index += 1
	var bounds := merge_game.get_base_board_bounds()
	var size := Vector2(bounds.size.x * data.obstacle_width_ratio, bounds.size.y * data.obstacle_height_ratio * 0.7)
	var rock := merge_game.spawn_gimmick_object()
	rock.configure_rock(size, data.obstacle_durability, true)
	rock.position = Vector2(_section_center(section).x, bounds.position.y - size.y)
	rock.linear_velocity = Vector2(0.0, 120.0)
	rocks.append(rock)
	falling_rocks.append(rock)
	rock_quiet_time[rock.get_instance_id()] = 0.0
	merge_game.suppress_danger_line(0.5)
	_log("ROCK FALL", "section=%d durability=%d" % [section, data.obstacle_durability])
	return true


func _process_falling_rocks(delta: float) -> void:
	for index in range(falling_rocks.size() - 1, -1, -1):
		var rock := falling_rocks[index]
		if not is_instance_valid(rock):
			falling_rocks.remove_at(index)
			continue
		var id := rock.get_instance_id()
		var quiet := float(rock_quiet_time.get(id, 0.0))
		quiet = quiet + delta if rock.linear_velocity.length() < 12.0 else 0.0
		rock_quiet_time[id] = quiet
		if quiet >= 1.0:
			rock.freeze = true
			falling_rocks.remove_at(index)
			rock_quiet_time.erase(id)


func _set_portals(layout: int) -> void:
	var bounds := merge_game.get_base_board_bounds()
	if layout == 0:
		portal_entrance = Vector2(bounds.position.x + bounds.size.x * 0.16, bounds.position.y + bounds.size.y * 0.78)
		portal_exit = Vector2(bounds.position.x + bounds.size.x * 0.84, bounds.position.y + bounds.size.y * 0.48)
	else:
		portal_entrance = Vector2(bounds.position.x + bounds.size.x * 0.84, bounds.position.y + bounds.size.y * 0.78)
		portal_exit = Vector2(bounds.position.x + bounds.size.x * 0.16, bounds.position.y + bounds.size.y * 0.48)
	active_portals = true
	merge_game.gimmick_overlay.show_portals(portal_entrance, portal_exit)
	_log("PORTAL", "layout=%d" % layout)


func _process_portals() -> void:
	var now := Time.get_ticks_msec()
	for ball in _valid_balls():
		if now < ball.portal_cooldown_until_msec or ball.position.distance_to(portal_entrance) > 42.0:
			continue
		var inward := -1.0 if portal_exit.x > merge_game.get_base_board_bounds().get_center().x else 1.0
		ball.position = portal_exit + Vector2(45.0 * inward, 0.0)
		ball.linear_velocity = Vector2(180.0 * inward, 0.0)
		ball.portal_cooldown_until_msec = now + 500
		_log("PORTAL MOVE", _ball_log(ball))


func _activate_gravity_field() -> void:
	var positions := [Vector2(0.22, 0.48), Vector2(0.78, 0.48), Vector2(0.5, 0.55)]
	var normalized: Vector2 = positions[sequence_index % positions.size()]
	sequence_index += 1
	var bounds := merge_game.get_base_board_bounds()
	gravity_center = bounds.position + bounds.size * normalized
	active_gravity = true
	merge_game.gimmick_overlay.show_gravity(gravity_center, data.effect_radius)
	_log("GRAVITY", "center=%s" % str(gravity_center))


func _apply_gravity_force() -> void:
	for ball in _valid_balls():
		var offset := gravity_center - ball.position
		var distance := offset.length()
		if distance <= 1.0 or distance > data.effect_radius:
			continue
		var falloff := 1.0 - 0.5 * distance / data.effect_radius
		ball.apply_central_force(offset.normalized() * data.field_force * falloff * ball.mass)


func _activate_danger_zone() -> void:
	var order: Array[int] = [0, 2, 1]
	var section: int = order[sequence_index % order.size()]
	sequence_index += 1
	danger_rect = _section_rect(section)
	active_danger = true
	merge_game.gimmick_overlay.show_zone(danger_rect, Color(1.0, 0.12, 0.22, 0.22), "위험 영역")
	_log("DANGER ZONE", "section=%d" % section)


func _apply_danger_turn_tick() -> void:
	for ball in _valid_balls():
		if danger_rect.has_point(ball.position):
			ball.set_hazard_turns(ball.hazard_turns + 1)
			if ball.hazard_turns >= data.danger_turn_threshold:
				var old_stage := ball.merge_level + 1
				if ball.merge_level <= 0:
					merge_game.remove_gimmick_ball(ball)
				else:
					var replacement := merge_game.replace_ball_stage(ball, ball.merge_level - 1)
					if is_instance_valid(replacement):
						replacement.set_hazard_turns(0)
				_log("DANGER TRIGGER", "stage=%d" % old_stage)
		else:
			ball.set_hazard_turns(0)


func _shuffle_queue() -> void:
	var before := merge_game.get_future_levels(3)
	var after := merge_game.reverse_future_queue(3)
	battle.update_gimmick_ui("다음: 일반 공격 · %d턴" % data.normal_attack_interval, "큐 %s → %s" % [_stage_list(before), _stage_list(after)])
	_log("QUEUE SHUFFLE", "%s -> %s" % [_stage_list(before), _stage_list(after)])


func _stage_list(levels: Array[int]) -> String:
	var stages: Array[String] = []
	for level in levels:
		stages.append(str(level + 1))
	return " / ".join(stages)


func _stage_sequence(default_values: Array[int]) -> Array[int]:
	return data.stage_sequence if not data.stage_sequence.is_empty() else default_values


func _activate_stage_seal() -> void:
	var stages := _stage_sequence([2, 3, 4])
	var stage := stages[sequence_index % stages.size()]
	sequence_index += 1
	merge_game.set_sealed_stage(stage)
	_log("SEAL", "stage=%d" % stage)


func _rotate_weakness() -> void:
	var stages := _stage_sequence([2, 3, 4, 5])
	var current_index := stages.find(weakness_stage)
	weakness_stage = stages[(current_index + 1) % stages.size()] if current_index >= 0 else stages[0]
	_update_weakness_detail()
	_log("WEAKNESS", "stage=%d" % weakness_stage)


func _update_weakness_detail() -> void:
	if not is_instance_valid(battle):
		return
	var stages := _stage_sequence([2, 3, 4, 5])
	var index := stages.find(weakness_stage)
	var next_stage := stages[(index + 1) % stages.size()] if index >= 0 else stages[0]
	battle.update_gimmick_ui("다음: %s · %d턴" % [_next_action_name(), remaining_turns], "약점 %d단계 → 다음 %d단계" % [weakness_stage, next_stage])


func _activate_drop_restriction() -> void:
	var section := sequence_index % 3
	sequence_index += 1
	var rect := _section_rect(section)
	merge_game.set_blocked_drop_zone(rect)
	merge_game.gimmick_overlay.show_zone(rect, Color(0.95, 0.15, 0.15, 0.24), "투하 금지  X")
	_log("DROP BLOCK", "section=%d" % section)


func _swap_balls() -> bool:
	var candidates := _valid_balls()
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.y < b.position.y)
	var first: MergeBall
	var second: MergeBall
	for i in candidates.size():
		for j in range(i + 1, candidates.size()):
			if candidates[i].merge_level == candidates[j].merge_level:
				continue
			if absi(candidates[i].merge_level - candidates[j].merge_level) <= 1:
				first = candidates[i]
				second = candidates[j]
				break
		if first != null:
			break
	if first == null or second == null:
		return false
	var first_position := first.position
	var second_position := second.position
	for ball in [first, second]:
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		ball.freeze = true
		ball.collision_layer = 0
		ball.collision_mask = 0
	merge_game.suppress_danger_line(0.5)
	var tween := _create_gimmick_tween().set_parallel(true)
	tween.tween_property(first, "position", second_position, data.animation_duration)
	tween.tween_property(second, "position", first_position, data.animation_duration)
	await tween.finished
	for ball in [first, second]:
		if is_instance_valid(ball):
			ball.collision_layer = 1
			ball.collision_mask = 1
			ball.freeze = false
	_log("SWAP", "%s <-> %s" % [_ball_log(first), _ball_log(second)])
	return true


func _spawn_life_bubble() -> void:
	var bounds := merge_game.get_base_board_bounds()
	life_bubble = merge_game.spawn_gimmick_object()
	life_bubble.configure_life_bubble(42.0, data.life_health, data.life_max_shield)
	life_bubble.position = Vector2(bounds.get_center().x, bounds.end.y - bounds.size.y * 0.17)
	_log("LIFE BUBBLE", "hp=%d" % data.life_health)


func _attack_life_bubble() -> bool:
	if not is_instance_valid(life_bubble):
		return false
	var failed := life_bubble.take_life_hit()
	_log("LIFE HIT", "hp=%d shield=%d" % [life_bubble.durability, life_bubble.shield])
	if failed:
		battle.fail_gimmick_level("생명 방울이 파괴되었습니다")
	return true


func _on_merge_completed(merged_ball: MergeBall) -> void:
	if not active or not is_instance_valid(merged_ball):
		return
	if data.kind == TestGimmickData.Kind.SPLIT and split_target_merge_pending:
		merged_ball.set_split_targeted(true)
		split_targets.append(merged_ball)
		split_target_merge_pending = false
	for index in range(rocks.size() - 1, -1, -1):
		var rock := rocks[index]
		if not is_instance_valid(rock):
			rocks.remove_at(index)
			continue
		if merged_ball.position.distance_to(rock.position) <= data.effect_radius:
			if rock.take_obstacle_hit():
				rocks.remove_at(index)
				rock.queue_free()
			_log("ROCK DAMAGE", "remaining=%d" % rock.durability)
	if is_instance_valid(life_bubble) and merged_ball.position.distance_to(life_bubble.position) <= data.life_shield_radius:
		life_bubble.grant_shield()
		_log("LIFE SHIELD", "shield=%d" % life_bubble.shield)


func _on_merge_registered(result_level: int, origin: Vector2, chain_index: int, source_ids: Array[int], involved_cursed: bool) -> void:
	if not active:
		return
	if data.kind == TestGimmickData.Kind.SPLIT:
		for target in split_targets:
			if is_instance_valid(target) and source_ids.has(target.get_instance_id()):
				split_target_merge_pending = true
				target.set_split_targeted(false)
				split_targets.erase(target)
				break
	if data.kind == TestGimmickData.Kind.ENEMY_STANCE:
		var merge_side := _stance_side_for_x(origin.x, merge_game.get_base_board_bounds())
		if merge_side == 0:
			stance_left_merges += 1
		else:
			stance_right_merges += 1
		if stance_mode in [0, 2]:
			stance_damage_records.append({
				"origin": origin,
				"multiplier": data.stance_weak_multiplier if merge_side != stance_side else 1.0,
				"stance": _stance_side_name(stance_side),
				"side": _stance_side_name(merge_side),
			})
		_log("STANCE MERGE", "side=%s chain=%d left=%d right=%d" % [_stance_side_name(merge_side), chain_index, stance_left_merges, stance_right_merges])
	if data.kind == TestGimmickData.Kind.MERGE_CURSE and is_instance_valid(curse_target) and curse_target.get_instance_id() in source_ids:
		if involved_cursed:
			player.take_damage(data.counter_damage)
			_log("CURSE COUNTER", "damage=%d" % data.counter_damage)
		_clear_curse()
	if data.kind == TestGimmickData.Kind.MERGE_SEQUENCE and rune_turns_left > 0 and rune_progress < rune_pattern.size():
		var result_stage := result_level + 1
		if result_stage == rune_pattern[rune_progress]:
			rune_progress += 1
			if rune_progress >= rune_pattern.size():
				enemy.take_damage(data.rune_bonus_damage)
				skip_next_attack = true
				rune_turns_left = 0
				rune_cooldown = data.rune_restart_delay
				_log("RUNE COMPLETE", "bonus_damage=%d" % data.rune_bonus_damage)
			_update_action_ui()
	if data.kind == TestGimmickData.Kind.MERGE_ECHO and duration_remaining > 0 and echo_current_markers.size() < data.echo_markers_per_turn:
		echo_current_markers.append(origin)
		var all_markers: Array[Vector2] = echo_pending_markers.duplicate()
		all_markers.append_array(echo_current_markers)
		merge_game.gimmick_overlay.show_echo_markers(all_markers)
		_log("ECHO MARKER", "chain=%d position=%s" % [chain_index, str(origin)])
	if data.kind == TestGimmickData.Kind.REWIND:
		for source_id in source_ids:
			rewind_records.erase(source_id)


func _update_rewind_labels(turns: int) -> void:
	for record in rewind_records.values():
		var ball := record.get("ball") as MergeBall
		if is_instance_valid(ball):
			ball.set_rewind_turns(turns)


func _update_action_ui() -> void:
	if not active or not is_instance_valid(battle):
		return
	if data.kind == TestGimmickData.Kind.SPLIT and next_is_special:
		_ensure_split_targets()
	var primary := "다음: %s · %d턴" % [_next_action_name(), remaining_turns]
	var detail := ""
	if duration_remaining > 0:
		primary = "%s 유지 · %d턴" % [data.display_name, duration_remaining]
	match data.kind:
		TestGimmickData.Kind.TILT:
			detail = "다음 방향 %s" % ("오른쪽 낮음" if direction_sign > 0 else "왼쪽 낮음")
		TestGimmickData.Kind.SHOCKWAVE_HORIZONTAL:
			detail = "다음 충격파 %s" % ("오른쪽" if direction_sign > 0 else "왼쪽")
		TestGimmickData.Kind.ROCK_FALL:
			var rock_order: Array[int] = [0, 2, 1]
			var upcoming_section: int = rock_order[sequence_index % rock_order.size()]
			detail = "낙하 예정 %s" % ["좌", "중앙", "우"][upcoming_section]
			if next_is_special:
				merge_game.gimmick_overlay.show_telegraph(_section_rect(upcoming_section))
			else:
				merge_game.gimmick_overlay.clear_telegraph()
		TestGimmickData.Kind.PORTAL:
			detail = "다음 배치 %s" % ("우측 입구 → 좌측 출구" if sequence_index == 0 else "좌측 입구 → 우측 출구")
		TestGimmickData.Kind.WEAKNESS:
			var stages := _stage_sequence([2, 3, 4, 5])
			var index := stages.find(weakness_stage)
			detail = "약점 %d단계 → 다음 %d단계" % [weakness_stage, stages[(index + 1) % stages.size()]]
		TestGimmickData.Kind.SEAL_STAGE when duration_remaining > 0:
			detail = "봉인 %d단계" % (merge_game.sealed_stage_index + 1)
		TestGimmickData.Kind.QUEUE_SHUFFLE:
			detail = "미래 공 %s" % _stage_list(merge_game.get_future_levels(3))
		TestGimmickData.Kind.LIFE_BUBBLE when is_instance_valid(life_bubble):
			detail = "생명 방울 HP %d · 보호막 %d" % [life_bubble.durability, life_bubble.shield]
		TestGimmickData.Kind.FLOOD:
			detail = "현재 수면 %s" % ("활성" if flood_active else "대기")
		TestGimmickData.Kind.MERGE_CURSE:
			detail = "저주 대상 %s" % ("지정됨" if is_instance_valid(curse_target) else "없음")
		TestGimmickData.Kind.MERGE_SEQUENCE:
			primary = "일반 공격 · %d턴" % auxiliary_attack_turns
			detail = "%s · %s" % [_rune_text(), ("남은 %d턴" % rune_turns_left if rune_turns_left > 0 else "새 룬 %d턴" % rune_cooldown)]
		TestGimmickData.Kind.COMBO_BARRIER when duration_remaining > 0:
			detail = "CHAIN 1 ×%.2f · 2 ×%.1f · 3+ ×%.1f" % [data.first_chain_multiplier, data.second_chain_multiplier, data.later_chain_multiplier]
		TestGimmickData.Kind.TRAPDOOR:
			detail = "구덩이 %s" % (["좌", "중앙", "우"][trapdoor_section] if trapdoor_section >= 0 else "대기")
		TestGimmickData.Kind.BUMPER:
			detail = "범퍼 %s" % ("활성" if is_instance_valid(bumper) else "대기")
		TestGimmickData.Kind.WEAK_ZONE:
			primary = "일반 공격 %d턴 · 구역 이동 %d턴" % [auxiliary_attack_turns, weak_zone_move_turns]
			var zone_order: Array[int] = [0, 2, 1]
			var zone_index := zone_order.find(weak_zone_section)
			var next_zone := zone_order[(zone_index + 1) % zone_order.size()]
			detail = "약점 구역 %s → 다음 %s" % [["좌", "중앙", "우"][weak_zone_section], ["좌", "중앙", "우"][next_zone]]
		TestGimmickData.Kind.MERGE_ECHO:
			detail = "잔향 대기 %d · 이번 턴 %d" % [echo_pending_markers.size(), echo_current_markers.size()]
		TestGimmickData.Kind.REWIND:
			detail = "시간 표식 %d개" % rewind_records.size()
		TestGimmickData.Kind.MIRROR_DROP:
			detail = "MIRROR %s" % ("활성" if mirror_active else "대기")
		TestGimmickData.Kind.BOARD_STATE_TARGETING:
			var criterion_name := "HEIGHT" if targeting_criterion == 0 else "COUNT"
			primary = "%s → %s · %d턴" % [criterion_name, _section_name(targeting_section), remaining_turns]
			if targeting_mode == 2:
				detail = "분석형 · 다음 기준 %s" % ("COUNT" if targeting_criterion == 0 else "HEIGHT")
			else:
				detail = "보드 상태에 따라 TARGET 갱신"
		TestGimmickData.Kind.ENEMY_STANCE:
			var stance_name := _stance_side_name(stance_side)
			var opposite_name := _stance_side_name(1 - stance_side)
			primary = "STANCE: %s %s" % [stance_name, ("←" if stance_side == 0 else "→")]
			match stance_mode:
				0:
					detail = "WEAK: %s · x%.2f" % [opposite_name, data.stance_weak_multiplier]
				1:
					detail = "ATTACK: %s · %d턴" % [stance_name, remaining_turns]
				_:
					detail = "WEAK: %s · ATTACK: %s · %d턴" % [opposite_name, stance_name, remaining_turns]
		TestGimmickData.Kind.STAGE_FILTER_BOARD:
			if filter_mode == 0:
				primary = "PASS: 1~%d" % filter_left_pass
				detail = "일반 공격 · %d턴" % remaining_turns
			elif filter_mode == 1:
				primary = "LEFT 1~%d | RIGHT 1~%d" % [filter_left_pass, filter_right_pass]
				detail = "일반 공격 · %d턴" % remaining_turns
			else:
				primary = "FILTER CHANGE · %d" % filter_change_turns
				var next_left := data.filter_left_pass_stage if filter_swapped else data.filter_right_pass_stage
				var next_right := data.filter_right_pass_stage if filter_swapped else data.filter_left_pass_stage
				detail = "L 1~%d | R 1~%d · NEXT L 1~%d | R 1~%d" % [filter_left_pass, filter_right_pass, next_left, next_right]
	battle.update_gimmick_ui(primary, detail)


func _next_action_name() -> String:
	return data.display_name if next_is_special else "일반 공격"


func _ball_log(ball: MergeBall) -> String:
	if not is_instance_valid(ball):
		return "invalid"
	return "id=%d stage=%d position=%s" % [ball.get_instance_id(), ball.merge_level + 1, str(ball.position)]


func _log(event: String, detail: String) -> void:
	if data != null and data.debug_logging:
		print("[GIMMICK %s] %s | %s" % [data.display_name, event, detail])


func _create_gimmick_tween() -> Tween:
	var tween := create_tween()
	active_tweens.append(tween)
	return tween
