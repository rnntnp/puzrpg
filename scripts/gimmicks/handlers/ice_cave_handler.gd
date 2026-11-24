extends "res://scripts/gimmicks/handlers/normal_monster_experiment_handler.gd"

const CaveConfig = preload("res://scripts/gimmicks/configs/ice_cave_config.gd")
const BossConfig = preload("res://scripts/gimmicks/configs/ice_boss_experiment_config.gd")
const BossActions = preload("res://scripts/gimmicks/ice_boss_actions.gd")
const Augments = preload("res://scripts/gimmicks/configs/ice_cave_augments.gd")
const Card = Augments.Card

var boss_pattern: BossActions.Pattern
var boss_actions: BossActions
var augments: Augments
var wave_clear_heal := 0
var owned: Array[int] = []
var lightning_hits := 0
var pending_lightning := 0
var buildup_stacks := 0
var turn_merges := 0
var choosing := false
var vulnerable_target: Fighter
var vulnerability_turns := 0
var sacrifice_button: Button
var sacrifice_used := false
var sacrifice_pending := false


func _on_configured() -> void:
	var source := data.tuning as CaveConfig
	var config := source.duplicate() as CaveConfig
	var source_formation := source.formation_source.test_gimmick.tuning as FormationConfig
	config.layouts = []
	for index in range(config.waves.size()):
		var preset := source_formation.layouts[config.formation_presets[index] - 1].duplicate()
		preset.preview_wave = config.waves[index]
		config.layouts.append(preset)
	config.draft = null
	augments = config.augments
	wave_clear_heal = config.wave_clear_heal
	var bosses := source.ice_boss_source.test_gimmick.tuning as BossConfig
	boss_pattern = bosses.bosses[config.ice_boss_index]
	if config.allow_boss_freeze_at_any_ball_level:
		boss_pattern = boss_pattern.duplicate(true) as BossActions.Pattern
		boss_pattern.first_freeze.limit_target_levels = false
		if boss_pattern.second_freeze != null:
			boss_pattern.second_freeze.limit_target_levels = false
	data = data.duplicate() as TestGimmickData
	data.tuning = config
	super._on_configured()
	draft_visual = attach_visual_layer(DraftVisual.new())
	draft_visual.card_selected.connect(_select_card)
	sacrifice_button = Button.new()
	sacrifice_button.position = Vector2(470, 33)
	sacrifice_button.custom_minimum_size = Vector2(155, 34)
	sacrifice_button.pressed.connect(_use_sacrifice)
	draft_visual.root.add_child(sacrifice_button)
	draft_visual.root.move_child(sacrifice_button, draft_visual.modal.get_index())
	merge_game.player_merge_registered.connect(_heal_on_merge)
	merge_game.player_drop_companion = _spawn_satellite
	player.health_changed.connect(_on_augment_health_changed)
	_refresh_draft()
	formation_visual.enable_manual_target_reticle()
	battle.player_skill_controller.select_skill_target = _apply_targeted_skill
	for button in formation_visual.layout_buttons:
		button.get_parent().hide()


func _on_enemy_changed() -> void:
	if battle.current_enemy_index > 0:
		player.heal(wave_clear_heal)
		offered = augments.offer(owned, _board_saturation())
		if not offered.is_empty():
			choosing = true
			busy = true
			merge_game.set_input_enabled(false)
			draft_visual.show_choices(offered, _card_ranks(), augments, battle.current_enemy_index, formation.waves.size())
			owns_pause = not get_tree().paused
			get_tree().paused = true
			return
	_start_wave()


func _start_wave() -> void:
	sacrifice_used = false
	sacrifice_pending = false
	_set_vulnerability(null, 0)
	pending_lightning = 0
	layout_index = battle.current_enemy_index
	# Stage 66 presents its own draft before the formation is spawned.
	var visual := draft_visual
	draft_visual = null
	super._on_enemy_changed()
	draft_visual = visual
	if layout_index == formation.waves.size() - 1:
		boss_actions = BossActions.new()
		add_child(boss_actions)
		boss_actions.intent_changed.connect(_show_boss_intent)
		boss_actions.configure(self, front[0], boss_pattern, _boss_attack, _boss_backlash,
			formation.counterattack_seconds, _boss_burst)
	if is_instance_valid(sacrifice_button):
		_refresh_sacrifice_button()


func _select_card(card: int) -> void:
	if not choosing or not offered.has(card) or not player.is_alive():
		return
	owned.append(card)
	offered.clear()
	draft_visual.hide_choices()
	var removed := _apply_board_augment(card)
	_refresh_draft()
	_release_pause()
	if removed:
		await get_tree().physics_frame
		await merge_game.wait_until_board_settled()
	if not active or not player.is_alive():
		return
	turn_attack_visual.take_origins()
	choosing = false
	_start_wave()
	busy = false
	if battle.battle_running and enemy.is_alive():
		merge_game.set_input_enabled(true)


func _card_ranks() -> Array[int]:
	var ranks: Array[int] = []
	ranks.resize(Augments.NAMES.size())
	ranks.fill(0)
	for card in owned:
		ranks[card] = 1
	return ranks


func _refresh_draft() -> void:
	draft_visual.update_build(_card_ranks(), lightning_hits, augments, buildup_stacks,
		_has_resolve())
	_refresh_sacrifice_button()


func _refresh_sacrifice_button() -> void:
	sacrifice_button.visible = owned.has(Card.SACRIFICE)
	sacrifice_button.disabled = sacrifice_used or player.current_health <= augments.sacrifice_hp
	sacrifice_button.text = "희생 · 강화 준비" if sacrifice_pending else (
		"희생 · 사용 완료" if sacrifice_used else "희생 · HP %d" % augments.sacrifice_hp
	)


func _use_sacrifice() -> void:
	if not active or busy or choosing or not battle.battle_running or not owned.has(Card.SACRIFICE):
		return
	if sacrifice_used or player.current_health <= augments.sacrifice_hp or not merge_game.can_accept_autoplay_drop():
		return
	sacrifice_used = true
	sacrifice_pending = true
	player.take_damage(augments.sacrifice_hp)


func _on_augment_health_changed(_health: int, _maximum: int) -> void:
	_refresh_draft()


func _board_saturation() -> float:
	var area := 0.0
	for ball: MergeBall in merge_game.get_active_balls():
		if not ball.merge_locked:
			area += PI * pow(ball.get_radius(), 2)
	var width := merge_game.board_inner_right - merge_game.board_inner_left
	return area / maxf(1.0, width * (merge_game.board_inner_bottom - merge_game.danger_line_y))


func _apply_board_augment(card: int) -> bool:
	var balls := merge_game.get_active_balls().filter(func(ball: MergeBall) -> bool: return not ball.merge_locked)
	var removed := false
	if card >= Card.EVOLUTION_1 and card <= Card.EVOLUTION_3:
		var minimum := card - Card.EVOLUTION_1 + 1
		merge_game.set_random_drop_window(minimum, augments.drop_window_size)
		for ball: MergeBall in balls:
			if ball.merge_level < minimum:
				merge_game.remove_gimmick_ball(ball)
				removed = true
	elif card == Card.CLEANUP:
		balls.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
			if a.merge_level != b.merge_level:
				return a.merge_level > b.merge_level
			if a.position.y != b.position.y:
				return a.position.y < b.position.y
			return a.get_instance_id() < b.get_instance_id())
		for index in range(mini(augments.cleanup_count, balls.size())):
			merge_game.remove_gimmick_ball(balls[index])
			removed = true
	return removed


func _spawn_satellite(sequence_id: int, launch_position: Vector2, velocity: Vector2) -> void:
	if not owned.has(Card.SATELLITE):
		return
	while _satellite_turn_active(sequence_id) and not merge_game.dropped_ball_has_landed:
		await get_tree().physics_frame
	if not _satellite_turn_active(sequence_id):
		return
	await get_tree().create_timer(augments.satellite_launch_delay, false).timeout
	if not _satellite_turn_active(sequence_id):
		return
	var level := merge_game.random_drop_minimum
	var satellite := merge_game.spawn_gimmick_ball(level, launch_position, velocity)
	while _satellite_turn_active(sequence_id) and is_instance_valid(satellite) and not satellite.has_landed():
		await get_tree().physics_frame


func _satellite_turn_active(sequence_id: int) -> bool:
	return active and is_inside_tree() and battle.battle_running and player.is_alive() \
		and not merge_game.is_game_over and merge_game.drop_sequence_id == sequence_id


func _heal_on_merge(_points: int, _level: int) -> void:
	if active and player.is_alive() and owned.has(Card.HEAL):
		player.heal(augments.heal_per_merge)


func _on_player_ball_dropped() -> void:
	battle.player_skill_controller.cancel_skill_target()
	turn_merges = 0
	super._on_player_ball_dropped()


func _collect_merge_attack(damage: int, combo: int, points: int, origin: Vector2, level: int, sequence: int) -> void:
	if choosing or not active or not battle.battle_running or not player.is_alive():
		return
	turn_merges += 1
	if owned.has(Card.LIGHTNING):
		lightning_hits += 1
		if lightning_hits >= augments.lightning_hit_interval:
			lightning_hits = 0
			pending_lightning += 1
	super._collect_merge_attack(damage, combo, points, origin, level, sequence)
	_refresh_draft()


func modify_player_damage(damage: int, _level := -1, _combo := 1, _origin := Vector2.ZERO) -> int:
	var bonus := buildup_stacks * augments.buildup_bonus
	buildup_stacks = 0
	if sacrifice_pending:
		bonus += augments.sacrifice_bonus
		sacrifice_pending = false
	if _has_resolve():
		bonus += augments.resolve_bonus
	for index in range(mini(turn_merges - 2, 2), -1, -1):
		if owned.has(Card.COMBO_2 + index):
			bonus += augments.combo_bonuses[index]
			break
	return roundi(damage * (1.0 + bonus))


func _has_resolve() -> bool:
	return owned.has(Card.RESOLVE) and player.current_health <= player.max_health * augments.resolve_threshold


func on_turn_completed() -> void:
	if active and not busy and enemy.is_alive() and player.is_alive() and turn_merges == 0 and owned.has(Card.BUILDUP):
		buildup_stacks = mini(buildup_stacks + 1, augments.max_stacks)
		_refresh_draft()
	await super.on_turn_completed()


func _shotgun_multiplier() -> float:
	return augments.shotgun_multiplier if owned.has(Card.SHOTGUN) else 1.0


func _select_attack_target(fighter: Fighter) -> void:
	if battle.player_skill_controller.awaiting_skill_target:
		battle.player_skill_controller.try_use_skill_on(fighter)
		return
	super._select_attack_target(fighter)


func _apply_targeted_skill(fighter: Fighter, turns: int) -> int:
	if not active or busy or not battle.battle_running or not is_instance_valid(fighter) or not fighter.is_alive():
		return 0
	if not front.has(fighter) and not rear.has(fighter):
		return 0
	super._select_attack_target(fighter)
	if attack_target != fighter:
		return 0
	var total := vulnerability_turns + turns if vulnerable_target == fighter else turns
	_set_vulnerability(fighter, total)
	return total


func _set_vulnerability(fighter: Fighter, turns: int) -> void:
	vulnerable_target = fighter if turns > 0 else null
	vulnerability_turns = turns
	formation_visual.set_targeted_weakness(vulnerable_target, turns)


func _allocate_damage(damage: int, roster: Array[Fighter]) -> Array[PackedInt32Array]:
	var slot := roster.find(vulnerable_target) if is_instance_valid(vulnerable_target) else -1
	return Allocation.allocate(damage, roster.find(attack_target), _get_hp(roster), _get_damage_redirects(roster),
		_shotgun_multiplier(), slot, Weakness.incoming_damage_multiplier)


func _on_formation_fighter_defeated(fighter: Fighter) -> void:
	if fighter == vulnerable_target:
		_set_vulnerability(null, 0)
	super._on_formation_fighter_defeated(fighter)


func _apply_followup_damage() -> void:
	for index in range(pending_lightning):
		_ensure_attack_target()
		if not is_instance_valid(attack_target) or not battle.battle_running:
			break
		var roster: Array[Fighter] = front + rear
		var target := attack_target
		var receiver := Allocation.damage_receiver(roster.find(target), _get_hp(roster), _get_damage_redirects(roster))
		if roster[receiver] != target:
			_on_damage_redirected(target)
		target = roster[receiver]
		draft_visual.show_hit(target.character_sprite.global_position, false, augments.lightning_damage, 0, false)
		_damage_formation([target], augments.lightning_damage)
	pending_lightning = 0


func _hit_player(fighter: Fighter) -> void:
	var previous_hp := player.current_health
	super._hit_player(fighter)
	_after_enemy_hit(fighter, previous_hp)


func _enemy_attack_reduction() -> int:
	return augments.damage_reduction if owned.has(Card.STONE) else 0


func _after_enemy_hit(fighter: Fighter, previous_hp: int) -> void:
	if not player.is_alive() or player.current_health >= previous_hp or not owned.has(Card.REVENGE_1):
		return
	var targets: Array[Fighter] = front + rear if owned.has(Card.REVENGE_2) else [fighter]
	_damage_formation(targets, augments.revenge_damage)


func _damage_formation(targets: Array[Fighter], damage: int) -> void:
	var spent := 0
	for fighter in targets:
		if not is_instance_valid(fighter) or not fighter.is_alive():
			continue
		var applied := mini(damage, fighter.current_health)
		fighter.take_damage(applied, false)
		turn_attack_visual.show_impact(fighter, applied, not fighter.is_alive())
		spent += applied
		if not fighter.is_alive():
			_on_formation_fighter_defeated(fighter)
			formation_visual.retire_defeated_fighter(fighter, formation.impact_flash_seconds)
			if front.has(fighter):
				front[front.find(fighter)] = null
			elif rear.has(fighter):
				rear[rear.find(fighter)] = null
	if spent > 0 and enemy.is_alive():
		enemy.take_damage(spent)


func _advance_enemy_actions() -> void:
	if vulnerability_turns > 0:
		_set_vulnerability(vulnerable_target, vulnerability_turns - 1)
	if is_instance_valid(boss_actions):
		await boss_actions.advance_turn()
	else:
		await super._advance_enemy_actions()


func _show_boss_intent(intent: StatusEffectData, counter: int) -> void:
	var fighter := boss_actions.enemy
	if not is_instance_valid(fighter) or not fighter.is_alive():
		return
	var kind := ActionIcons.Kind.ATTACK if intent == BossActions.AttackIntent else ActionIcons.Kind.SKILL
	formation_visual.set_action_preview(fighter, kind, counter, false, 0, true, intent.icon)


func _boss_attack() -> void:
	var fighter := boss_actions.enemy
	var damage := roundi(fighter.attack_power * (1.0 - weaken))
	var previous_hp := player.current_health
	fighter.attack_with_damage(player, maxi(0, damage - shield - _enemy_attack_reduction()))
	shield = 0
	weaken = 0.0
	_after_enemy_hit(fighter, previous_hp)


func _boss_burst(hits: Array[int]) -> void:
	var previous_hp := player.current_health
	for hit in hits:
		if not player.is_alive():
			break
		player.take_damage(maxi(0, hit - _enemy_attack_reduction()))
	_after_enemy_hit(boss_actions.enemy, previous_hp)


func _boss_backlash(damage: int) -> void:
	var fighter := boss_actions.enemy
	if not fighter.is_alive():
		return
	var applied := mini(damage, fighter.current_health)
	if applied <= 0:
		return
	fighter.take_damage(applied)
	if not fighter.is_alive():
		_on_formation_fighter_defeated(fighter)
		formation_visual.retire_defeated_fighter(fighter, formation.impact_flash_seconds)
		front[0] = null
	enemy.take_damage(applied)


func _on_cleanup() -> void:
	if is_instance_valid(battle) and is_instance_valid(battle.player_skill_controller):
		battle.player_skill_controller.cancel_skill_target()
		battle.player_skill_controller.select_skill_target = Callable()
	if is_instance_valid(player) and player.health_changed.is_connected(_on_augment_health_changed):
		player.health_changed.disconnect(_on_augment_health_changed)
	if is_instance_valid(merge_game):
		merge_game.player_drop_companion = Callable()
		merge_game.random_drop_minimum = 0
		merge_game.random_drop_count = 5
		if merge_game.player_merge_registered.is_connected(_heal_on_merge):
			merge_game.player_merge_registered.disconnect(_heal_on_merge)
	if is_instance_valid(boss_actions):
		boss_actions.cleanup()
	super._on_cleanup()
