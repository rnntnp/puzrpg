class_name IceSkillController
extends Node

const IceSkillDataClass = preload("res://scripts/ice_skill_data.gd")
const IceCastEffectScene = preload("res://scenes/ice_cast_effect.tscn")

var merge_game: MergeGame
var skill: IceSkillDataClass
var caster: Fighter
var telegraphed_target_ids: Array[int] = []
var active_cast_target_id := 0


func configure(game: MergeGame, skill_data: IceSkillDataClass, caster_fighter: Fighter) -> void:
	cancel_telegraph()
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
	var frozen_count := 0
	var pending_target_ids: Array[int] = telegraphed_target_ids.duplicate()
	telegraphed_target_ids.clear()
	for target_id in pending_target_ids:
		var target := instance_from_id(target_id) as MergeBall
		if not _is_valid_freeze_target(target):
			continue
		var froze_target: bool = await _cast_freeze_at(target)
		if froze_target:
			frozen_count += 1
	await get_tree().create_timer(skill.freeze_effect_duration).timeout
	print("[ICE FREEZE] count=%d | durability=%d" % [frozen_count, skill.ice_durability])
	return frozen_count


func cancel_telegraph() -> void:
	for target_id in telegraphed_target_ids:
		var ball := instance_from_id(target_id) as MergeBall
		if is_instance_valid(ball):
			ball.set_ice_targeted(false)
	telegraphed_target_ids.clear()
	active_cast_target_id = 0


func _cast_freeze_at(ball: MergeBall) -> bool:
	if not is_instance_valid(ball) or not is_instance_valid(caster):
		return false
	active_cast_target_id = ball.get_instance_id()
	ball.set_ice_targeted(true)
	var effect := IceCastEffectScene.instantiate() as IceCastEffect
	get_tree().current_scene.add_child(effect)
	effect.play(caster.get_spell_origin_global_position(), ball.global_position)
	await effect.arrived
	var final_target := _get_active_cast_target()
	active_cast_target_id = 0
	if not _is_valid_freeze_target(final_target):
		return false
	final_target.set_ice_targeted(false)
	final_target.freeze_in_ice(skill.ice_durability)
	return true


func _get_active_cast_target() -> MergeBall:
	if active_cast_target_id <= 0:
		return null
	return instance_from_id(active_cast_target_id) as MergeBall


func _is_valid_freeze_target(ball: MergeBall) -> bool:
	if not is_instance_valid(ball) or ball.merge_locked or ball.is_queued_for_deletion():
		return false
	if not ball.is_ice_frozen:
		return ball.merge_level + 1 >= skill.target_min_level
	return ball.ice_durability < skill.ice_durability


func clear_all_ice() -> void:
	cancel_telegraph()
	if merge_game == null:
		return
	for ball in _get_frozen_balls():
		ball.break_ice(false)


func _select_targets(count: int) -> Array[MergeBall]:
	var unfrozen: Array[MergeBall] = []
	var damaged_frozen: Array[MergeBall] = []
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_queued_for_deletion() or ball.ice_targeted:
			continue
		if not ball.is_ice_frozen:
			unfrozen.append(ball)
		elif ball.ice_durability < skill.ice_durability:
			damaged_frozen.append(ball)
	var pool := _select_stage_pool(unfrozen, count)
	if pool.is_empty():
		pool = _select_stage_pool(damaged_frozen, count)
	var result: Array[MergeBall] = []
	for ball in pool:
		result.append(ball)
		if result.size() >= count:
			break
	return result


func _select_stage_pool(candidates: Array[MergeBall], desired_count: int) -> Array[MergeBall]:
	var selected: Array[MergeBall] = []
	# Search strictly from the preferred minimum upward: e.g. 3 -> 4 -> 5 -> 6.
	for candidate_level in range(skill.target_min_level, 12):
		var at_level: Array[MergeBall] = []
		for ball in candidates:
			if ball.merge_level + 1 == candidate_level:
				at_level.append(ball)
		at_level.shuffle()
		for ball in at_level:
			selected.append(ball)
			if selected.size() >= desired_count:
				return selected
	return selected


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
			telegraphed_target_ids.remove_at(index)
			removed_targets += 1
	if removed_targets <= 0:
		return
	var result_id := result_ball.get_instance_id()
	if result_id not in telegraphed_target_ids:
		telegraphed_target_ids.append(result_id)
	result_ball.set_ice_targeted(true)
	if removed_targets < 2:
		return
	var replacements := _select_targets(1)
	if replacements.is_empty():
		return
	var replacement: MergeBall = replacements.front()
	replacement.set_ice_targeted(true)
	telegraphed_target_ids.append(replacement.get_instance_id())
