extends "res://scripts/gimmicks/handlers/circle_xpbd_pond_handler.gd"

const Experiment = preload("res://scripts/gimmicks/configs/ice_boss_experiment_config.gd")
const Pattern = preload("res://scripts/gimmicks/configs/ice_boss_pattern.gd")
const BossActions = preload("res://scripts/gimmicks/ice_boss_actions.gd")
const FormationVisual = preload("res://scripts/gimmicks/visuals/pond_formation_visual.gd")
const TurnAttackVisual = preload("res://scripts/gimmicks/visuals/pond_turn_attack_visual.gd")
const RestartSelection := &"ice_boss_experiment_selection"

var experiment: Experiment
var pattern: Pattern
var boss_actions: BossActions
var attack_visual: TurnAttackVisual
var pending_damage := 0
var pending_combo := 0
var drop_started_msec := 0
var restarting := false
var previous_turn_gate := false
var previous_quiet_msec := 0
var board_space := RID()
var board_was_active := false
var displayed_intent: StatusEffectData


func _on_configured() -> void:
	super._on_configured()
	experiment = data.tuning as Experiment
	var selection := int(GameSession.get_meta(RestartSelection, 0))
	GameSession.remove_meta(RestartSelection)
	pattern = experiment.bosses[selection]
	enemy.set_character_data(pattern.character)
	battle.right_bar.fill_color = pattern.character.health_bar_color
	battle.right_bar.queue_redraw()
	battle._apply_shadow_visual(battle.right_fighter_shadow, enemy, pattern.character)
	battle.enemy_progress_label.text = enemy.display_name

	var buttons := FormationVisual.new()
	battle.add_child(buttons)
	visual_layers.append(buttons)
	var names := PackedStringArray()
	for boss in experiment.bosses:
		names.append(boss.character.display_name)
	buttons.add_layout_buttons(names, selection)
	buttons.layout_selected.connect(_restart_with_boss)

	attack_visual = attach_visual_layer(TurnAttackVisual.new()) as TurnAttackVisual
	attack_visual.tuning = experiment
	merge_game.player_merge_result_created.connect(attack_visual.track_ball)
	previous_turn_gate = merge_game.wait_for_turn_before_next_input
	previous_quiet_msec = merge_game.merge_quiet_settlement_msec
	merge_game.wait_for_turn_before_next_input = true
	merge_game.merge_quiet_settlement_msec = roundi(experiment.settlement_quiet_seconds * 1000.0)
	merge_game.player_merge_attack_collector = _collect_merge_attack
	boss_actions = BossActions.new()
	add_child(boss_actions)
	boss_actions.intent_changed.connect(_update_intent)
	boss_actions.configure(self, enemy, pattern, _normal_attack, enemy.take_damage, experiment.counterattack_seconds)


func _restart_with_boss(index: int) -> void:
	if restarting or not active:
		return
	restarting = true
	merge_game.set_input_enabled(false)
	_reload_battle.call_deferred(index)


func _reload_battle(index: int) -> void:
	GameSession.set_meta(RestartSelection, index)
	var result := get_tree().reload_current_scene()
	if result != OK:
		GameSession.remove_meta(RestartSelection)
		restarting = false
		if _can_act() and not busy:
			merge_game.set_input_enabled(true)


func _on_player_ball_dropped() -> void:
	super._on_player_ball_dropped()
	drop_started_msec = Time.get_ticks_msec()


func _collect_merge_attack(damage: int, combo: int, _points: int, origin: Vector2, level: int, sequence: int) -> void:
	if not _can_act():
		return
	pending_damage += battle.monster_action_controller.route_player_damage(damage, level, combo, origin, sequence)
	pending_combo = maxi(pending_combo, combo)


func on_turn_completed() -> void:
	if busy or not _can_act():
		return
	busy = true
	merge_game.set_input_enabled(false)
	var damage := pending_damage
	battle.result_max_combo = maxi(battle.result_max_combo, pending_combo)
	pending_damage = 0
	pending_combo = 0
	var origins := attack_visual.take_origins()
	if damage > 0:
		await _settle_player_attack(damage, origins)
	else:
		attack_visual.finish_shots()
	if not _can_act():
		return

	await boss_actions.advance_turn()
	if not _can_act():
		return
	busy = false
	merge_game.set_input_enabled(true)


func _settle_player_attack(damage: int, origins: PackedVector2Array) -> void:
	if origins.is_empty():
		origins.append(player.get_spell_origin_global_position())
	var settlement_seconds := float(Time.get_ticks_msec() - drop_started_msec) / 1000.0
	var speed := clampf(settlement_seconds / experiment.acceleration_after_seconds, 1.0, experiment.maximum_attack_speed)
	var beat := clampf(experiment.seconds_per_target / speed, experiment.minimum_attack_seconds,
		maxf(experiment.minimum_attack_seconds, experiment.maximum_attack_seconds))
	_pause_board()
	player.play_cast_animation()
	attack_visual.start_volley(origins, PackedVector2Array([enemy.character_sprite.global_position]),
		PackedInt32Array([damage]), beat, false)
	await get_tree().create_timer(beat * TurnAttackVisual.TRAVEL_FRACTION, false, false, true).timeout
	if _can_act():
		var applied := mini(damage, enemy.current_health)
		attack_visual.show_impact(enemy, applied, applied == enemy.current_health)
		enemy.take_damage(applied, false)
	await get_tree().create_timer(beat * (1.0 - TurnAttackVisual.TRAVEL_FRACTION), false, false, true).timeout
	if is_instance_valid(attack_visual):
		attack_visual.finish_shots()
	_restore_board()


func _normal_attack() -> void:
	var reduced_damage := roundi(enemy.attack_power * (1.0 - weaken))
	enemy.attack_with_damage(player, maxi(0, reduced_damage - shield))
	shield = 0
	weaken = 0.0


func _update_intent(intent: StatusEffectData, counter: int) -> void:
	if displayed_intent != null and displayed_intent != intent:
		battle.right_status_effects.remove_effect(displayed_intent.effect_id)
	battle.right_status_effects.set_effect(intent, counter)
	displayed_intent = intent
	if intent == BossActions.BurstIntent:
		battle.update_gimmick_ui("", "내구도 0인 얼음은 폭발할 때 보스에게 역류합니다.")
	else:
		battle.update_gimmick_ui("", "")


func _refresh() -> void:
	# The inherited loadout still affects merges, but this stage supplies its own intent.
	pass


func _can_act() -> bool:
	return active and not restarting and battle.battle_running and enemy.is_alive() and player.is_alive()


func _pause_board() -> void:
	board_space = merge_game.get_world_2d().space
	board_was_active = PhysicsServer2D.space_is_active(board_space)
	merge_game.attack_presentation_paused = true
	PhysicsServer2D.space_set_active(board_space, false)


func _restore_board() -> void:
	if board_space.is_valid():
		PhysicsServer2D.space_set_active(board_space, board_was_active)
		board_space = RID()
		if is_instance_valid(merge_game):
			merge_game.attack_presentation_paused = false


func _on_cleanup() -> void:
	_restore_board()
	boss_actions.cleanup()
	if displayed_intent != null:
		battle.right_status_effects.remove_effect(displayed_intent.effect_id)
	merge_game.player_merge_attack_collector = Callable()
	merge_game.wait_for_turn_before_next_input = previous_turn_gate
	merge_game.merge_quiet_settlement_msec = previous_quiet_msec
	if is_instance_valid(attack_visual) and merge_game.player_merge_result_created.is_connected(attack_visual.track_ball):
		merge_game.player_merge_result_created.disconnect(attack_visual.track_ball)
	super._on_cleanup()


func _exit_tree() -> void:
	_restore_board()
