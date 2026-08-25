class_name IceSkillController
extends Node

const IceSkillDataClass = preload("res://scripts/ice_skill_data.gd")
const IceCastEffectScene = preload("res://scenes/ice_cast_effect.tscn")
const MERGE_RESULT_GRACE_MSEC := 500
const MAX_CAST_TARGET_ATTEMPTS := 16

var merge_game: MergeGame
var skill: IceSkillDataClass
var caster: Fighter
var telegraphed_target_ids: Array[int] = []
var active_cast_target_id := 0
var cast_resolution_active := false


func configure(game: MergeGame, skill_data: IceSkillDataClass, caster_fighter: Fighter) -> void:
	_cancel_pending_targets(true)
	merge_game = game
	skill = skill_data
	caster = caster_fighter
	if not merge_game.merge_completed.is_connected(_on_merge_completed):
		merge_game.merge_completed.connect(_on_merge_completed)
	if not merge_game.ice_telegraph_merge_resolved.is_connected(_on_ice_telegraph_merge_resolved):
		merge_game.ice_telegraph_merge_resolved.connect(_on_ice_telegraph_merge_resolved)


func begin_telegraph() -> int:
	if skill == null:
		return 0
	cancel_telegraph()
	var selected_targets := _select_targets(skill.freeze_count)
	for ball in selected_targets:
		ball.set_ice_targeted(true)
		telegraphed_target_ids.append(ball.get_instance_id())
	return telegraphed_target_ids.size()


func execute_telegraphed() -> int:
	if skill == null:
		return 0
	var finish_delay := skill.freeze_effect_duration
	var action_durability := skill.ice_durability
	cast_resolution_active = true
	_reserve_ready_targets()
	await _wait_for_marked_merge_results()
	if not cast_resolution_active:
		_clear_tracked_target_visuals()
		return 0
	_prune_unusable_targets()
	_fill_missing_targets(skill.freeze_count)
	_reserve_ready_targets()
	var frozen_count := 0
	var attempts := 0
	while frozen_count < skill.freeze_count and attempts < MAX_CAST_TARGET_ATTEMPTS and cast_resolution_active:
		if telegraphed_target_ids.is_empty():
			_fill_missing_targets(skill.freeze_count - frozen_count)
			_reserve_ready_targets()
			if telegraphed_target_ids.is_empty():
				break
		attempts += 1
		var target_id: int = telegraphed_target_ids.pop_front()
		var target := instance_from_id(target_id) as MergeBall
		if not _is_valid_freeze_target(target):
			continue
		target.set_ice_cast_reserved(true)
		var froze_target: bool = await _cast_freeze_at(target)
		if froze_target:
			frozen_count += 1
		elif is_instance_valid(target):
			target.set_ice_targeted(false)
			target.set_ice_cast_reserved(false)
	cast_resolution_active = false
	_clear_tracked_target_visuals()
	await get_tree().create_timer(finish_delay).timeout
	print("[ICE FREEZE] count=%d | durability=%d" % [frozen_count, action_durability])
	return frozen_count


func cancel_telegraph() -> void:
	_cancel_pending_targets(false)


func cancel_pending_on_enemy_defeat() -> void:
	_cancel_pending_targets(true)


func _cancel_pending_targets(keep_active_cast: bool) -> void:
	cast_resolution_active = false
	for target_id in telegraphed_target_ids:
		var ball := instance_from_id(target_id) as MergeBall
		if is_instance_valid(ball):
			ball.set_ice_targeted(false)
			ball.set_ice_cast_reserved(false)
	telegraphed_target_ids.clear()
	var preserved_active_id := active_cast_target_id if keep_active_cast else 0
	if not keep_active_cast:
		var active_target := _get_active_cast_target()
		if is_instance_valid(active_target):
			active_target.set_ice_targeted(false)
			active_target.set_ice_cast_reserved(false)
		active_cast_target_id = 0
	if merge_game != null:
		for child in merge_game.get_active_balls():
			if child is MergeBall:
				if child.get_instance_id() == preserved_active_id:
					continue
				if child.ice_targeted:
					child.set_ice_targeted(false)
				if child.ice_cast_reserved:
					child.set_ice_cast_reserved(false)


func _cast_freeze_at(ball: MergeBall) -> bool:
	if not is_instance_valid(ball) or not is_instance_valid(caster):
		return false
	var cast_durability := skill.ice_durability
	active_cast_target_id = ball.get_instance_id()
	ball.set_ice_targeted(true)
	var effect := IceCastEffectScene.instantiate() as IceCastEffect
	get_tree().current_scene.add_child(effect)
	effect.play(caster.get_spell_origin_global_position(), ball.global_position)
	await effect.arrived
	var final_target := _get_active_cast_target()
	active_cast_target_id = 0
	if is_instance_valid(final_target):
		final_target.set_ice_cast_reserved(false)
	if not _is_valid_freeze_target(final_target):
		return false
	final_target.set_ice_targeted(false)
	var applied_durability := cast_durability
	if final_target.is_ice_frozen:
		applied_durability += final_target.ice_durability
	final_target.freeze_in_ice(applied_durability)
	return true


func _get_active_cast_target() -> MergeBall:
	if active_cast_target_id <= 0:
		return null
	return instance_from_id(active_cast_target_id) as MergeBall


func _is_valid_freeze_target(ball: MergeBall) -> bool:
	if not is_instance_valid(ball) or ball.merge_locked or ball.is_queued_for_deletion():
		return false
	return true


func clear_all_ice() -> void:
	cancel_telegraph()
	if merge_game == null:
		return
	for ball in _get_frozen_balls():
		ball.break_ice(false)


func _select_targets(count: int) -> Array[MergeBall]:
	var unfrozen: Array[MergeBall] = []
	var damaged_frozen: Array[MergeBall] = []
	var full_frozen: Array[MergeBall] = []
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_queued_for_deletion() or ball.ice_targeted or ball.ice_cast_reserved:
			continue
		if not ball.is_ice_frozen:
			unfrozen.append(ball)
		elif ball.ice_durability < skill.ice_durability:
			damaged_frozen.append(ball)
		else:
			full_frozen.append(ball)
	var priority_result: Array[MergeBall] = []
	_append_stage_pool(priority_result, unfrozen, count, false)
	_append_stage_pool(priority_result, damaged_frozen, count, false)
	_append_stage_pool(priority_result, full_frozen, count, false)
	_append_stage_pool(priority_result, unfrozen, count, true)
	_append_stage_pool(priority_result, damaged_frozen, count, true)
	_append_stage_pool(priority_result, full_frozen, count, true)
	if priority_result.is_empty():
		return priority_result
	var random_candidates: Array[MergeBall] = []
	if skill.random_primary_candidate_count > 0:
		_append_stage_pool(
			random_candidates, unfrozen, skill.random_primary_candidate_count, false
		)
		_append_stage_pool(
			random_candidates, unfrozen, skill.random_primary_candidate_count, true
		)
		random_candidates.shuffle()
	if skill.nearby_unfrozen_count <= 0 or count <= 1:
		if random_candidates.is_empty():
			return priority_result
		var random_result: Array[MergeBall] = []
		for ball in random_candidates:
			random_result.append(ball)
			if random_result.size() >= count:
				return random_result
		for ball in priority_result:
			if ball in random_result:
				continue
			random_result.append(ball)
			if random_result.size() >= count:
				break
		return random_result
	var center: MergeBall = priority_result.front() as MergeBall
	if not random_candidates.is_empty():
		center = random_candidates.front() as MergeBall
	var result: Array[MergeBall] = [center]
	var nearby_unfrozen: Array[MergeBall] = []
	for ball in unfrozen:
		if ball != center:
			nearby_unfrozen.append(ball)
	nearby_unfrozen.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return center.global_position.distance_squared_to(a.global_position) < center.global_position.distance_squared_to(b.global_position)
	)
	var nearby_limit := mini(skill.nearby_unfrozen_count, count - 1)
	for ball in nearby_unfrozen:
		result.append(ball)
		if result.size() >= nearby_limit + 1:
			break
	if result.size() >= count:
		return result
	for ball in priority_result:
		if ball in result:
			continue
		result.append(ball)
		if result.size() >= count:
			break
	return result


func _reserve_ready_targets() -> void:
	for target_id in telegraphed_target_ids:
		var target := instance_from_id(target_id) as MergeBall
		if _is_valid_freeze_target(target):
			target.set_ice_cast_reserved(true)


func _wait_for_marked_merge_results() -> void:
	var deadline := Time.get_ticks_msec() + MERGE_RESULT_GRACE_MSEC
	while cast_resolution_active and Time.get_ticks_msec() < deadline:
		var has_pending_merge := false
		for target_id in telegraphed_target_ids:
			var target := instance_from_id(target_id) as MergeBall
			if is_instance_valid(target) and target.merge_locked:
				has_pending_merge = true
				break
		if not has_pending_merge:
			return
		await get_tree().physics_frame


func _prune_unusable_targets() -> void:
	for index in range(telegraphed_target_ids.size() - 1, -1, -1):
		var target := instance_from_id(telegraphed_target_ids[index]) as MergeBall
		if _is_valid_freeze_target(target):
			continue
		if is_instance_valid(target):
			target.set_ice_targeted(false)
			target.set_ice_cast_reserved(false)
		telegraphed_target_ids.remove_at(index)


func _fill_missing_targets(desired_pending_count: int) -> void:
	var missing_count := maxi(0, desired_pending_count - telegraphed_target_ids.size())
	if missing_count <= 0:
		return
	for target in _select_targets(missing_count):
		target.set_ice_targeted(true)
		if cast_resolution_active:
			target.set_ice_cast_reserved(true)
		telegraphed_target_ids.append(target.get_instance_id())


func _clear_tracked_target_visuals() -> void:
	for target_id in telegraphed_target_ids:
		var target := instance_from_id(target_id) as MergeBall
		if is_instance_valid(target):
			target.set_ice_targeted(false)
			target.set_ice_cast_reserved(false)
	telegraphed_target_ids.clear()


func _append_stage_pool(
	selected: Array[MergeBall],
	candidates: Array[MergeBall],
	desired_count: int,
	search_lower_stages: bool
) -> void:
	if selected.size() >= desired_count:
		return
	var stage_order: Array[int] = []
	if search_lower_stages:
		for candidate_level in range(skill.target_min_level - 1, 0, -1):
			stage_order.append(candidate_level)
	else:
		for candidate_level in range(skill.target_min_level, 12):
			stage_order.append(candidate_level)
	for candidate_level in stage_order:
		var at_level: Array[MergeBall] = []
		for ball in candidates:
			if ball.merge_level + 1 == candidate_level:
				at_level.append(ball)
		at_level.shuffle()
		for ball in at_level:
			selected.append(ball)
			if selected.size() >= desired_count:
				return


func _get_frozen_balls() -> Array[MergeBall]:
	var result: Array[MergeBall] = []
	if merge_game == null:
		return result
	for child in merge_game.get_active_balls():
		if child is MergeBall and child.is_ice_frozen and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _on_merge_completed(_merged_ball: MergeBall) -> void:
	for ball in _get_frozen_balls():
		ball.damage_ice(1)


func _on_ice_telegraph_merge_resolved(
	result_ball: MergeBall,
	source_ids: Array[int],
	_marked_source_count: int
) -> void:
	if not is_instance_valid(result_ball):
		return
	var active_cast_target := _get_active_cast_target()
	if is_instance_valid(active_cast_target) and active_cast_target.get_instance_id() in source_ids:
		active_cast_target_id = result_ball.get_instance_id()
	var removed_targets := 0
	for index in range(telegraphed_target_ids.size() - 1, -1, -1):
		var target_id := telegraphed_target_ids[index]
		if target_id in source_ids:
			var target := instance_from_id(target_id) as MergeBall
			if is_instance_valid(target):
				target.set_ice_targeted(false)
				target.set_ice_cast_reserved(false)
			telegraphed_target_ids.remove_at(index)
			removed_targets += 1
	if removed_targets <= 0:
		if cast_resolution_active:
			result_ball.set_ice_targeted(false)
			result_ball.set_ice_cast_reserved(false)
		return
	var result_id := result_ball.get_instance_id()
	if result_id not in telegraphed_target_ids:
		telegraphed_target_ids.append(result_id)
	result_ball.set_ice_targeted(true)
	if cast_resolution_active:
		result_ball.set_ice_cast_reserved(true)
	if removed_targets < 2:
		return
	var replacements := _select_targets(1)
	if replacements.is_empty():
		return
	var replacement: MergeBall = replacements.front()
	replacement.set_ice_targeted(true)
	if cast_resolution_active:
		replacement.set_ice_cast_reserved(true)
	telegraphed_target_ids.append(replacement.get_instance_id())
