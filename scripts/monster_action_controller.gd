class_name MonsterActionController
extends Node

enum State {
	NORMAL_ATTACK,
	INGESTION_TELEGRAPH,
	INGESTION_RESPONSE,
}

const EnemyAttackEffect: StatusEffectData = preload("res://resources/effects/enemy_attack_countdown.tres")
const IngestionEffect: StatusEffectData = preload("res://resources/effects/ingestion_countdown.tres")
const IngestionLaunchEffect: StatusEffectData = preload("res://resources/effects/ingestion_launch_countdown.tres")
const IngestionHealEffect: StatusEffectData = preload("res://resources/effects/ingestion_heal_countdown.tres")
const IngestionDurabilityEffect: StatusEffectData = preload("res://resources/effects/ingestion_durability.tres")
const WeaknessEffect: StatusEffectData = preload("res://resources/effects/ingestion_vulnerable.tres")
const IceEffect: StatusEffectData = preload("res://resources/effects/ice_countdown.tres")
const IceSkillDataClass = preload("res://scripts/ice_skill_data.gd")
const IceSkillControllerClass = preload("res://scripts/ice_skill_controller.gd")
const HealCrossParticleBurstClass = preload("res://scripts/heal_cross_particle_burst.gd")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const IngestionLaunchProjectileClass = preload("res://scripts/ingestion_launch_projectile.gd")

var battle: Battle
var enemy: Fighter
var player: Fighter
var merge_game: MergeGame
var status_effects: StatusEffectBar
var applied_status_effects: StatusEffectBar
var durability_bar: WaterHealthBar
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
var next_action_is_ice := false
var ingestion_response_drop_sequence_id := -1


func configure(
	battle_node: Battle,
	enemy_fighter: Fighter,
	player_fighter: Fighter,
	game: MergeGame,
	effect_bar: StatusEffectBar,
	applied_effect_bar: StatusEffectBar,
	durability_ui: WaterHealthBar
) -> void:
	battle = battle_node
	enemy = enemy_fighter
	player = player_fighter
	merge_game = game
	status_effects = effect_bar
	applied_status_effects = applied_effect_bar
	durability_bar = durability_ui
	skill = enemy.character_data.ingestion_skill as IngestionSkillData
	ice_skill = enemy.character_data.ice_skill as IceSkillDataClass
	next_action_is_ice = ice_skill != null and ice_skill.starts_with_ice_action
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
	ingestion_response_drop_sequence_id = -1
	status_effects.clear_effects()
	applied_status_effects.clear_effects()
	durability_bar.clear_durability()
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
	_advance_weakness_turn()
	if using_test_gimmick:
		test_gimmick_controller.on_turn_completed()
		return
	remaining_turns = maxi(0, remaining_turns - 1)
	_update_ui()
	if state == State.INGESTION_TELEGRAPH:
		_update_ingestion_telegraph_visual()
	if remaining_turns > 0:
		if ice_skill != null and next_action_is_ice and remaining_turns == 1:
			var target_count := ice_controller.begin_telegraph()
			enemy.show_ice_eye_glow()
			if ice_skill.deals_direct_damage:
				var has_full_target_count := target_count >= ice_skill.freeze_count
				battle.show_player_damage_preview(
					enemy.attack_power if has_full_target_count else _get_ice_no_target_damage()
				)
			else:
				battle.clear_player_damage_preview()
		return

	match state:
		State.NORMAL_ATTACK:
			if ice_skill != null:
				if next_action_is_ice:
					_run_ice_turn()
				else:
					_run_ice_normal_attack()
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


func on_player_ball_started() -> void:
	if using_test_gimmick:
		return
	# 포식 실행 턴은 첫 착지에서 다음 공이 열리기 전에 입력을 막는다.
	# 실제 포식 연출이 끝나고 대응 상태가 준비될 때까지 이 잠금이 유지된다.
	if skill != null and state == State.INGESTION_TELEGRAPH and remaining_turns == 1:
		merge_game.set_input_enabled(false)
		return
	if ice_skill == null or state != State.NORMAL_ATTACK:
		return
	if next_action_is_ice and remaining_turns == 1:
		merge_game.set_input_enabled(false)


func route_player_damage(
	damage: int,
	merge_result_level_index := -1,
	combo_count := 1,
	merge_origin := Vector2.ZERO,
	attack_drop_sequence_id := -1
) -> int:
	if damage <= 0:
		return 0
	var routed_damage := damage
	if using_test_gimmick:
		routed_damage = test_gimmick_controller.modify_player_damage(
			damage, merge_result_level_index, combo_count, merge_origin
		)
	if routed_damage > 0 and vulnerable_turns > 0:
		routed_damage = roundi(
			float(routed_damage) * WeaknessEffect.incoming_damage_multiplier
		)
	if (
		not using_test_gimmick
		and routed_damage > 0
		and state == State.INGESTION_RESPONSE
		and current_durability > 0
		and (
			attack_drop_sequence_id < 0
			or attack_drop_sequence_id > ingestion_response_drop_sequence_id
		)
	):
		var absorbed := mini(current_durability, routed_damage)
		current_durability -= absorbed
		routed_damage -= absorbed
		_update_ui()
		print("[INGESTION DURABILITY] damage=%d | remaining=%d" % [absorbed, current_durability])
		# 내구도를 뚫고 HP까지 피해를 주는 타격은 take_damage()의 기존 피드백을 사용한다.
		if absorbed > 0 and routed_damage <= 0:
			battle.play_enemy_durability_hit_feedback(absorbed)
		if current_durability <= 0:
			_interrupt_ingestion()
	return routed_damage


func add_weakness_turns(turns: int) -> int:
	if turns <= 0:
		return vulnerable_turns
	vulnerable_turns += turns
	applied_status_effects.set_effect(WeaknessEffect, vulnerable_turns)
	return vulnerable_turns


func on_enemy_defeated() -> void:
	vulnerable_turns = 0
	applied_status_effects.remove_effect(WeaknessEffect.effect_id)
	if using_test_gimmick:
		var has_next_enemy: bool = battle.current_enemy_index + 1 < battle.level_data.enemies.size()
		if not has_next_enemy and test_gimmick_controller.should_finish_committed_action_after_enemy_defeat():
			using_test_gimmick = false
			return
		if not has_next_enemy or not test_gimmick_controller.should_preserve_between_enemies():
			test_gimmick_controller.cleanup()
		using_test_gimmick = false
		return
	enemy.clear_visual_override()
	enemy.hide_ingestion_glow()
	if swallowed_ball_level >= 0:
		merge_game.return_ingested_ball_to_board(
			swallowed_ball_level,
			enemy.get_ingestion_mouth_global_position()
		)
		battle.play_ingestion_spit_sfx()
	_state_version += 1
	_clear_target()
	status_effects.clear_effects()
	applied_status_effects.clear_effects()
	durability_bar.clear_durability()


func on_enemy_defeat_started() -> void:
	_state_version += 1
	if is_instance_valid(enemy):
		enemy.hide_ice_eye_glow()
	if ice_controller != null:
		ice_controller.cancel_pending_on_enemy_defeat()


func _enter_normal_attack() -> void:
	enemy.clear_visual_override()
	enemy.hide_ingestion_glow()
	enemy.hide_ice_eye_glow()
	state = State.NORMAL_ATTACK
	remaining_turns = (
		ice_skill.ice_action_interval
		if ice_skill != null and next_action_is_ice
		else enemy.enemy_attack_drop_interval
	)
	current_durability = 0
	status_effects.remove_effect(IngestionEffect.effect_id)
	status_effects.remove_effect(IngestionHealEffect.effect_id)
	if ice_skill != null and next_action_is_ice:
		status_effects.remove_effect(EnemyAttackEffect.effect_id)
		status_effects.set_effect(IceEffect, remaining_turns)
		battle.clear_player_damage_preview()
		if remaining_turns == 1:
			ice_controller.begin_telegraph()
			enemy.show_ice_eye_glow()
	else:
		status_effects.remove_effect(IceEffect.effect_id)
		status_effects.set_effect(EnemyAttackEffect, remaining_turns)
		battle.show_player_damage_preview(enemy.attack_power)
	durability_bar.clear_durability()
	applied_status_effects.remove_effect(IngestionDurabilityEffect.effect_id)


func _enter_ingestion_telegraph() -> void:
	battle.clear_player_damage_preview()
	enemy.hide_ingestion_glow()
	state = State.INGESTION_TELEGRAPH
	current_durability = 0
	durability_bar.clear_durability()
	applied_status_effects.remove_effect(IngestionDurabilityEffect.effect_id)
	active_ingestion_is_launch = _is_launch_ingestion()
	remaining_turns = skill.telegraph_turns
	_update_ingestion_telegraph_visual()
	status_effects.remove_effect(EnemyAttackEffect.effect_id)
	status_effects.remove_effect(IceEffect.effect_id)
	status_effects.remove_effect(IngestionHealEffect.effect_id)
	status_effects.set_effect(IngestionEffect, remaining_turns)
	_select_target()


func _execute_ingestion() -> void:
	if not is_instance_valid(target_ball):
		_select_target()
	if not is_instance_valid(target_ball):
		print("[INGESTION] target unavailable; retrying telegraph")
		_enter_ingestion_telegraph()
		merge_game.set_input_enabled(true)
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
		if is_instance_valid(enemy) and enemy.is_alive() and is_instance_valid(player) and player.is_alive():
			merge_game.set_input_enabled(true)
		return
	battle.play_ingestion_swallow_sfx()
	enemy.set_visual_override(enemy.character_data.ingestion_swallowed_sprite)
	enemy.play_ingestion_squash()
	enemy.show_ingestion_glow(swallowed_color)
	state = State.INGESTION_RESPONSE
	remaining_turns = skill.get_response_turns(active_ingestion_is_launch)
	ingestion_response_drop_sequence_id = merge_game.drop_sequence_id
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
	if active_ingestion_is_launch:
		status_effects.set_effect(IngestionLaunchEffect, remaining_turns)
	else:
		status_effects.remove_effect(IngestionEffect.effect_id)
		status_effects.set_effect(IngestionHealEffect, remaining_turns)
	applied_status_effects.set_effect(IngestionDurabilityEffect, 0)
	_update_ui()
	await battle.show_first_ingestion_swallow_tutorial()
	merge_game.set_input_enabled(true)
	print("[INGESTION START] level=%d | durability=%d | turns=%d" % [
		swallowed_ball_level + 1, current_durability, remaining_turns
	])


func _interrupt_ingestion() -> void:
	_state_version += 1
	battle.clear_player_damage_preview()
	var interrupted_effect_id := (
		IngestionEffect.effect_id if active_ingestion_is_launch else IngestionHealEffect.effect_id
	)
	await status_effects.dismiss_effect_with_shake(interrupted_effect_id)
	if swallowed_ball_level >= 0:
		merge_game.return_ingested_ball_to_board(
			swallowed_ball_level,
			enemy.get_ingestion_mouth_global_position()
		)
		battle.play_ingestion_spit_sfx()
		swallowed_ball_level = -1
	add_weakness_turns(skill.interrupted_debuff_turns)
	print("[INGESTION INTERRUPTED] vulnerable_turns=%d" % vulnerable_turns)
	_enter_post_ingestion_state()


func _schedule_ingestion_success() -> void:
	var version := _state_version
	await get_tree().create_timer(0.8, true, false, true).timeout
	if version != _state_version or state != State.INGESTION_RESPONSE or current_durability <= 0:
		return
	_state_version += 1
	var resolved_ball_level := swallowed_ball_level
	swallowed_ball_level = -1
	enemy.play_ingestion_squash()
	if active_ingestion_is_launch:
		battle.clear_player_damage_preview()
		await _launch_ingested_ball_at_player(resolved_ball_level, active_launch_damage)
		print("[INGESTION SUCCEEDED] launch_damage=%d" % active_launch_damage)
	else:
		enemy.heal(skill.heal_amount)
		var heal_burst := HealCrossParticleBurstClass.new()
		get_tree().current_scene.add_child(heal_burst)
		heal_burst.play(enemy.global_position + Vector2(0.0, 12.0))
		print("[INGESTION SUCCEEDED] heal=%d" % skill.heal_amount)
	if player.is_alive():
		_enter_post_ingestion_state()


func _launch_ingested_ball_at_player(level: int, damage: int) -> void:
	var ball_data := BallCatalogClass.get_ball(level) as BallData
	if ball_data == null:
		player.take_damage(damage)
		return
	var projectile := IngestionLaunchProjectileClass.new() as IngestionLaunchProjectile
	get_tree().current_scene.add_child(projectile)
	battle.play_ingestion_spit_sfx()
	projectile.play(
		enemy.get_ingestion_mouth_global_position(),
		player.global_position.x,
		ball_data
	)
	await projectile.crossed_player
	if is_instance_valid(player) and player.is_alive():
		player.take_damage(damage)
	await projectile.flight_finished


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


func _advance_weakness_turn() -> void:
	if vulnerable_turns <= 0:
		return
	vulnerable_turns -= 1
	if vulnerable_turns <= 0:
		applied_status_effects.remove_effect(WeaknessEffect.effect_id)
	else:
		applied_status_effects.set_effect(WeaknessEffect, vulnerable_turns)


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
	target_ball.set_ingestion_marked(true, enemy.character_data.health_bar_color)
	print("[INGESTION TARGET] level=%d" % (target_ball.merge_level + 1))


func _clear_target() -> void:
	if is_instance_valid(target_ball):
		target_ball.set_ingestion_marked(false)
	target_ball = null


func _on_target_replaced(ball: MergeBall) -> void:
	if state != State.INGESTION_TELEGRAPH:
		return
	target_ball = ball
	target_ball.set_ingestion_marked(true, enemy.character_data.health_bar_color)
	print("[INGESTION TARGET TRANSFER] level=%d" % (ball.merge_level + 1))


func _update_ui() -> void:
	match state:
		State.NORMAL_ATTACK:
			if ice_skill != null and next_action_is_ice:
				status_effects.remove_effect(EnemyAttackEffect.effect_id)
				status_effects.set_effect(IceEffect, remaining_turns)
			else:
				status_effects.remove_effect(IceEffect.effect_id)
				status_effects.set_effect(EnemyAttackEffect, remaining_turns)
		State.INGESTION_TELEGRAPH:
			status_effects.set_effect(IngestionEffect, remaining_turns)
		State.INGESTION_RESPONSE:
			status_effects.set_effect(_get_active_ingestion_effect(), remaining_turns)
	if state == State.INGESTION_RESPONSE:
		durability_bar.set_durability(current_durability, active_durability_max)
		if active_ingestion_is_launch and active_launch_damage > 0:
			battle.show_player_damage_preview(active_launch_damage)
		else:
			battle.clear_player_damage_preview()


func _run_ice_turn() -> void:
	_state_version += 1
	var action_version := _state_version
	merge_game.set_input_enabled(false)
	if not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		return
	battle.clear_player_damage_preview()
	if ice_skill.deals_direct_damage:
		enemy.attack(player)
		if not player.is_alive():
			enemy.hide_ice_eye_glow()
			return
	var frozen_count: int = await ice_controller.execute_telegraphed()
	if is_instance_valid(enemy):
		enemy.hide_ice_eye_glow()
	if action_version != _state_version:
		return
	if ice_skill.deals_direct_damage and frozen_count < ice_skill.freeze_count:
		var enhanced_damage := _get_ice_no_target_damage()
		var bonus_damage := maxi(0, enhanced_damage - enemy.attack_power)
		if bonus_damage > 0 and player.is_alive():
			player.take_damage(bonus_damage)
	next_action_is_ice = false
	_enter_normal_attack()
	if enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE


func _run_ice_normal_attack() -> void:
	battle.clear_player_damage_preview()
	enemy.attack(player)
	if not enemy.is_alive() or not player.is_alive():
		return
	next_action_is_ice = true
	_enter_normal_attack()


func _get_ice_no_target_damage() -> int:
	if ice_skill == null:
		return enemy.attack_power
	return roundi(float(enemy.attack_power) * ice_skill.no_target_damage_multiplier)


func _get_active_ingestion_effect() -> StatusEffectData:
	return IngestionLaunchEffect if active_ingestion_is_launch else IngestionHealEffect


func _update_ingestion_telegraph_visual() -> void:
	if remaining_turns <= 1:
		enemy.set_visual_override(enemy.character_data.ingestion_telegraph_sprite)
	else:
		enemy.clear_visual_override()
