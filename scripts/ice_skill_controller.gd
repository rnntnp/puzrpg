class_name IceSkillController
extends Node

const IceSkillDataClass = preload("res://scripts/ice_skill_data.gd")
const IceCastEffectScene = preload("res://scenes/ice_cast_effect.tscn")

var merge_game: MergeGame
var skill: IceSkillDataClass
var caster: Fighter


func configure(game: MergeGame, skill_data: IceSkillDataClass, caster_fighter: Fighter) -> void:
	merge_game = game
	skill = skill_data
	caster = caster_fighter
	if not merge_game.merge_completed.is_connected(_on_merge_completed):
		merge_game.merge_completed.connect(_on_merge_completed)


func execute() -> int:
	if skill == null:
		return 0
	var targets := _select_targets(skill.freeze_count)
	if targets.is_empty():
		return 0
	for ball in targets:
		ball.set_ice_targeted(true)
	await get_tree().create_timer(skill.target_highlight_duration).timeout
	for ball in targets:
		if is_instance_valid(ball):
			ball.set_ice_targeted(false)
			await _cast_freeze_at(ball)
	await get_tree().create_timer(skill.freeze_effect_duration).timeout
	print("[ICE FREEZE] count=%d | durability=%d" % [targets.size(), skill.ice_durability])
	return targets.size()


func _cast_freeze_at(ball: MergeBall) -> void:
	if not is_instance_valid(ball) or not is_instance_valid(caster):
		return
	var effect := IceCastEffectScene.instantiate() as IceCastEffect
	get_tree().current_scene.add_child(effect)
	effect.play(caster.get_spell_origin_global_position(), ball.global_position)
	await effect.arrived
	if is_instance_valid(ball):
		ball.freeze_in_ice(skill.ice_durability)


func clear_all_ice() -> void:
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
		if ball.merge_locked or ball.is_queued_for_deletion():
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
