class_name MonsterActionController
extends Node

enum State {
	NORMAL_ATTACK,
	INGESTION_TELEGRAPH,
	INGESTION_RESPONSE,
}

const EnemyAttackEffect: StatusEffectData = preload("res://resources/effects/enemy_attack_countdown.tres")
const IngestionEffect: StatusEffectData = preload("res://resources/effects/ingestion_countdown.tres")
const VulnerableEffect: StatusEffectData = preload("res://resources/effects/ingestion_vulnerable.tres")
const IceEffect: StatusEffectData = preload("res://resources/effects/ice_countdown.tres")
const IceSkillDataClass = preload("res://scripts/ice_skill_data.gd")
const IceSkillControllerClass = preload("res://scripts/ice_skill_controller.gd")

var battle: Battle
var enemy: Fighter
var player: Fighter
var merge_game: MergeGame
var status_effects: StatusEffectBar
var durability_label: Label
var skill: IngestionSkillData
var ice_skill: IceSkillDataClass
var ice_controller: IceSkillControllerClass
var test_gimmick_controller: TestGimmickController
var using_test_gimmick := false

var state := State.NORMAL_ATTACK
var remaining_turns := 0
var current_durability := 0
var active_durability_max := 0
var ingestion_executions := 0
var active_ingestion_is_launch := false
var active_launch_damage := 0
var launch_executions := 0
var swallowed_ball_level := -1
var target_ball: MergeBall
var vulnerable_turns := 0
var _state_version := 0


func configure(
	battle_node: Battle,
	enemy_fighter: Fighter,
	player_fighter: Fighter,
	game: MergeGame,
	effect_bar: StatusEffectBar,
	durability_ui: Label
) -> void:
	battle = battle_node
	enemy = enemy_fighter
	player = player_fighter
	merge_game = game
	status_effects = effect_bar
	durability_label = durability_ui
	skill = enemy.character_data.ingestion_skill as IngestionSkillData
	ice_skill = enemy.character_data.ice_skill as IceSkillDataClass
	ice_controller = get_node("IceSkillController") as IceSkillControllerClass
	test_gimmick_controller = get_node("TestGimmickController") as TestGimmickController
	ice_controller.configure(merge_game, ice_skill, enemy)
	enemy.clear_visual_override()
	enemy.hide_ingestion_glow()
	_state_version += 1
	_clear_target()
	swallowed_ball_level = -1
	active_durability_max = 0
	ingestion_executions = 0
	active_ingestion_is_launch = false
	active_launch_damage = 0
	launch_executions = 0
	vulnerable_turns = 0
	status_effects.clear_effects()
	durability_label.visible = false
	battle.clear_player_damage_preview()
	using_test_gimmick = battle.level_data != null and battle.level_data.test_gimmick != null
	if using_test_gimmick:
		test_gimmick_controller.configure(battle, enemy, player, merge_game, battle.level_data.test_gimmick)
		return
	if skill != null and skill.start_with_ingestion:
		_enter_ingestion_telegraph()
	else:
		_enter_normal_attack()
	if not merge_game.ingestion_target_replaced.is_connected(_on_target_replaced):
		merge_game.ingestion_target_replaced.connect(_on_target_replaced)


func on_ball_dropped() -> void:
	if enemy == null or not enemy.is_alive() or not player.is_alive():
		return
	if using_test_gimmick:
		test_gimmick_controller.on_turn_completed()
		return
	remaining_turns = maxi(0, remaining_turns - 1)
	_update_ui()
	if remaining_turns > 0:
		_schedule_vulnerability_tick()
		return

	match state:
		State.NORMAL_ATTACK:
			if ice_skill != null:
				_run_ice_turn()
				return
			battle.clear_player_damage_preview()
			enemy.attack(player)
			if skill == null:
				_enter_normal_attack()
			else:
				_enter_ingestion_telegraph()
		State.INGESTION_TELEGRAPH:
			_execute_ingestion()
		State.INGESTION_RESPONSE:
			_schedule_ingestion_success()
	_schedule_vulnerability_tick()


func route_player_damage(damage: int, merge_result_level_index := -1, combo_count := 1, merge_origin := Vector2.ZERO) -> int:
	if damage <= 0:
		return 0
	if using_test_gimmick:
		return test_gimmick_controller.modify_player_damage(damage, merge_result_level_index, combo_count, merge_origin)
	var hp_damage := damage
	if state == State.INGESTION_RESPONSE and current_durability > 0:
		var absorbed := mini(current_durability, hp_damage)
		current_durability -= absorbed
		hp_damage -= absorbed
		_update_ui()
		print("[INGESTION DURABILITY] damage=%d | remaining=%d" % [absorbed, current_durability])
		if current_durability <= 0:
			_interrupt_ingestion()
	if hp_damage > 0 and vulnerable_turns > 0:
		hp_damage = roundi(float(hp_damage) * skill.interrupted_damage_multiplier)
	return hp_damage


func on_enemy_defeated() -> void:
	if using_test_gimmick:
		var has_next_enemy: bool = battle.current_enemy_index + 1 < battle.level_data.enemies.size()
		if not has_next_enemy or not test_gimmick_controller.should_preserve_between_enemies():
			test_gimmick_controller.cleanup()
		using_test_gimmick = false
		return
	enemy.clear_visual_override()
	enemy.hide_ingestion_glow()
	if swallowed_ball_level >= 0:
		merge_game.return_ingested_ball_to_board(swallowed_ball_level)
	_state_version += 1
	_clear_target()
	status_effects.clear_effects()
	durability_label.visible = false
	if ice_controller != null:
		ice_controller.clear_all_ice()


func _enter_normal_attack() -> void:
	enemy.clear_visual_override()
	enemy.hide_ingestion_glow()
	state = State.NORMAL_ATTACK
	remaining_turns = enemy.enemy_attack_drop_interval
	current_durability = 0
	status_effects.remove_effect(IngestionEffect.effect_id)
	status_effects.remove_effect(IceEffect.effect_id)
	status_effects.set_effect(EnemyAttackEffect, remaining_turns)
	battle.show_player_damage_preview(enemy.attack_power)
	if ice_skill != null:
		status_effects.set_effect(IceEffect, remaining_turns)
	durability_label.visible = false


func _enter_ingestion_telegraph() -> void:
	battle.clear_player_damage_preview()
	enemy.hide_ingestion_glow()
	state = State.INGESTION_TELEGRAPH
	current_durability = 0
	durability_label.visible = false
	active_ingestion_is_launch = _is_launch_ingestion()
	enemy.set_visual_override(enemy.character_data.ingestion_telegraph_sprite)
	remaining_turns = skill.telegraph_turns
	status_effects.remove_effect(EnemyAttackEffect.effect_id)
	status_effects.remove_effect(IceEffect.effect_id)
	status_effects.set_effect(IngestionEffect, remaining_turns)
	_select_target()
	battle.status_label.text = "발사 포식 예고" if active_ingestion_is_launch else "회복 포식 예고"
	battle.status_label.modulate = Color("#d79cff")


func _execute_ingestion() -> void:
	if not is_instance_valid(target_ball):
		_select_target()
	if not is_instance_valid(target_ball):
		print("[INGESTION] target unavailable; retrying telegraph")
		_enter_ingestion_telegraph()
		return
	var consumed_ball := target_ball
	swallowed_ball_level = consumed_ball.merge_level
	var swallowed_color: Color = consumed_ball.ball_data.glow_color
	target_ball = null
	merge_game.set_input_enabled(false)
	var consumed := await merge_game.animate_ball_consumption(
		consumed_ball,
		enemy.get_ingestion_mouth_global_position()
	)
	if not consumed or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	enemy.set_visual_override(enemy.character_data.ingestion_swallowed_sprite)
	enemy.show_ingestion_glow(swallowed_color)
	state = State.INGESTION_RESPONSE
	remaining_turns = skill.response_turns
	active_durability_max = mini(
		skill.maximum_durability,
		skill.durability + skill.durability_increase_per_use * ingestion_executions
	)
	current_durability = active_durability_max
	if active_ingestion_is_launch:
		active_launch_damage = mini(
			skill.maximum_launch_damage,
			skill.launch_damage + skill.launch_damage_increase_per_use * launch_executions
		)
		launch_executions += 1
	else:
		active_launch_damage = 0
	ingestion_executions += 1
	status_effects.set_effect(IngestionEffect, remaining_turns)
	durability_label.visible = true
	battle.status_label.text = "포식 저지! 내구도를 파괴하세요"
	_update_ui()
	merge_game.set_input_enabled(true)
	print("[INGESTION START] level=%d | durability=%d | turns=%d" % [
		swallowed_ball_level + 1, current_durability, remaining_turns
	])


func _interrupt_ingestion() -> void:
	_state_version += 1
	if swallowed_ball_level >= 0:
		merge_game.return_ingested_ball_to_board(swallowed_ball_level)
		swallowed_ball_level = -1
	vulnerable_turns = skill.interrupted_debuff_turns
	status_effects.set_effect(VulnerableEffect, vulnerable_turns)
	battle.status_label.text = "포식 저지 성공! 삼킨 공이 보드로 돌아옵니다"
	battle.status_label.modulate = Color("#ffe066")
	print("[INGESTION INTERRUPTED] vulnerable_turns=%d" % vulnerable_turns)
	_enter_post_ingestion_state()
	status_effects.set_effect(VulnerableEffect, vulnerable_turns)


func _schedule_ingestion_success() -> void:
	var version := _state_version
	await get_tree().create_timer(0.8, true, false, true).timeout
	if version != _state_version or state != State.INGESTION_RESPONSE or current_durability <= 0:
		return
	_state_version += 1
	swallowed_ball_level = -1
	if active_ingestion_is_launch:
		enemy.attack_with_damage(player, active_launch_damage)
		battle.status_label.text = "포식 성공 · 발사 피해 %d" % active_launch_damage
		battle.status_label.modulate = Color("#ff765f")
		print("[INGESTION SUCCEEDED] launch_damage=%d" % active_launch_damage)
	else:
		enemy.heal(skill.heal_amount)
		battle.status_label.text = "포식 성공 · HP %d 회복" % skill.heal_amount
		battle.status_label.modulate = Color("#67dc83")
		print("[INGESTION SUCCEEDED] heal=%d" % skill.heal_amount)
	if player.is_alive():
		_enter_post_ingestion_state()


func _enter_post_ingestion_state() -> void:
	if skill.repeat_ingestion_without_normal_attack:
		_enter_ingestion_telegraph()
	else:
		_enter_normal_attack()


func _is_launch_ingestion() -> bool:
	if not skill.alternate_launch_and_heal:
		return skill.launch_damage > 0
	var even_ingestion := ingestion_executions % 2 == 0
	return even_ingestion if skill.launch_first else not even_ingestion


func _schedule_vulnerability_tick() -> void:
	if vulnerable_turns <= 0:
		return
	var version := _state_version
	await get_tree().create_timer(0.9, true, false, true).timeout
	if version != _state_version or vulnerable_turns <= 0:
		return
	vulnerable_turns -= 1
	if vulnerable_turns <= 0:
		status_effects.remove_effect(VulnerableEffect.effect_id)
	else:
		status_effects.set_effect(VulnerableEffect, vulnerable_turns)


func _select_target() -> void:
	_clear_target()
	var candidates: Array[MergeBall] = []
	for child in merge_game.get_active_balls():
		if child is MergeBall and not child.merge_locked and not child.is_queued_for_deletion():
			candidates.append(child)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level
	)
	target_ball = candidates.front()
	target_ball.set_ingestion_marked(true)
	print("[INGESTION TARGET] level=%d" % (target_ball.merge_level + 1))


func _clear_target() -> void:
	if is_instance_valid(target_ball):
		target_ball.set_ingestion_marked(false)
	target_ball = null


func _on_target_replaced(ball: MergeBall) -> void:
	if state != State.INGESTION_TELEGRAPH:
		return
	target_ball = ball
	print("[INGESTION TARGET TRANSFER] level=%d" % (ball.merge_level + 1))


func _update_ui() -> void:
	match state:
		State.NORMAL_ATTACK:
			status_effects.set_effect(EnemyAttackEffect, remaining_turns)
			if ice_skill != null:
				status_effects.set_effect(IceEffect, remaining_turns)
		State.INGESTION_TELEGRAPH, State.INGESTION_RESPONSE:
			status_effects.set_effect(IngestionEffect, remaining_turns)
	if state == State.INGESTION_RESPONSE:
		durability_label.text = "포식 내구도 %d / %d" % [current_durability, active_durability_max]


func _run_ice_turn() -> void:
	_state_version += 1
	merge_game.set_input_enabled(false)
	if not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		return
	battle.clear_player_damage_preview()
	enemy.attack(player)
	if not player.is_alive():
		return
	battle.status_label.text = "빙결 공격!"
	var frozen_count: int = await ice_controller.execute()
	if frozen_count == 0:
		battle.status_label.text = "빙결 대상 없음"
	_enter_normal_attack()
	if enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
