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
	var available_slots: int = skill.max_frozen_balls - _get_frozen_balls().size()
	if available_slots <= 0:
		return 0
	var targets := _select_targets(mini(skill.freeze_count, available_slots))
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
	var eligible: Array[MergeBall] = []
	var fallback: Array[MergeBall] = []
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_ice_frozen or ball.is_queued_for_deletion():
			continue
		fallback.append(ball)
		var displayed_level := ball.merge_level + 1
		if displayed_level >= skill.target_min_level and displayed_level <= skill.target_max_level:
			eligible.append(ball)
	var pool := eligible if not eligible.is_empty() else fallback
	pool.shuffle()
	if eligible.is_empty():
		pool.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
			return a.merge_level > b.merge_level
		)
	var result: Array[MergeBall] = []
	for ball in pool:
		result.append(ball)
		if result.size() >= count:
			break
	return result


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
