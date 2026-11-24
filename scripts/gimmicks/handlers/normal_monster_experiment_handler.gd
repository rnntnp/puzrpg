extends "res://scripts/gimmicks/handlers/pond_formation_handler.gd"

const MonsterSlot = preload("res://scripts/gimmicks/configs/normal_monster_slot.gd")
const HealerSlot = preload("res://scripts/gimmicks/configs/healer_monster_slot.gd")
const HealVisual = preload("res://scripts/gimmicks/visuals/monster_heal_visual.gd")
const GuardSlot = preload("res://scripts/gimmicks/configs/ice_guard_slot.gd")
const SpiritSlot = preload("res://scripts/gimmicks/configs/ice_spirit_slot.gd")
const Protection = preload("res://resources/effects/ice_guard_protection.tres")
const Weakness = preload("res://resources/effects/ingestion_vulnerable.tres")
const RestartSelection := &"normal_monster_experiment_selection"

class GuardState:
	var preparing := false
	var target: Fighter
	var order_index := 0
	var reset_this_turn := false

var slots_by_fighter: Dictionary[Fighter, MonsterSlot] = {}
var attack_counters: Dictionary[Fighter, int] = {}
var guards: Dictionary[Fighter, GuardState] = {}
var fighters_in_wave: Array[Fighter] = []
var restarting := false
var heal_visual: HealVisual
var protection_effect: StatusEffectData
var cold_weakness: StatusEffectData
var cold_turns := 0
var cold_refreshed := false
var spirit_hover: Dictionary[Fighter, Tween] = {}


func _on_configured() -> void:
	layout_index = int(GameSession.get_meta(RestartSelection, 0))
	GameSession.remove_meta(RestartSelection)
	protection_effect = Protection.duplicate() as StatusEffectData
	protection_effect.icon = ActionIcons.texture_for(ActionIcons.Kind.SHIELD)
	cold_weakness = Weakness.duplicate() as StatusEffectData
	cold_weakness.effect_id = &"ice_spirit_weakness"
	player.defeated.connect(_on_player_defeated)
	super._on_configured()
	formation_visual.action_preview_button.hide()
	heal_visual = attach_visual_layer(HealVisual.new()) as HealVisual
	heal_visual.z_index = 215


func _spawn_wave() -> void:
	_clear_cold_weakness()
	_clear_spirit_hover()
	_clear_guards()
	fighters_in_wave.clear()
	slots_by_fighter.clear()
	attack_counters.clear()
	super._spawn_wave()
	var front_index := 0
	var rear_index := 0
	for entry in _current_wave().slots:
		var slot := entry as MonsterSlot
		var fighter: Fighter
		if entry.column == 0:
			fighter = front[front_index]
			front_index += 1
		else:
			fighter = rear[rear_index]
			rear_index += 1
		if slot != null:
			slots_by_fighter[fighter] = slot
			attack_counters[fighter] = slot.initial_attack_counter
			if slot is GuardSlot:
				guards[fighter] = GuardState.new()
			elif slot is SpiritSlot:
				_start_spirit_hover(fighter, slot as SpiritSlot)
		fighters_in_wave.append(fighter)
		fighter.tree_exiting.connect(_on_formation_fighter_defeated.bind(fighter))


func _on_player_ball_dropped() -> void:
	super._on_player_ball_dropped()
	formation_visual.set_layouts_locked(false)


func _select_layout(index: int) -> void:
	if restarting or not active or index < 0 or index >= formation.layouts.size():
		return
	restarting = true
	merge_game.set_input_enabled(false)
	_reload_battle.call_deferred(index)


func _reload_battle(index: int) -> void:
	GameSession.set_meta(RestartSelection, index)
	if get_tree().reload_current_scene() != OK:
		GameSession.remove_meta(RestartSelection)
		restarting = false
		if battle.battle_running and not busy:
			merge_game.set_input_enabled(true)


func _advance_enemy_actions() -> void:
	cold_refreshed = false
	var ready: Array[Fighter] = []
	for fighter in front + rear:
		if not is_instance_valid(fighter) or not fighter.is_alive() or not attack_counters.has(fighter):
			continue
		if guards.has(fighter) and _advance_guard_protection(fighter):
			continue
		attack_counters[fighter] -= 1
		if attack_counters[fighter] == 0:
			ready.append(fighter)
	_update_action_previews()
	var attacked := false
	for fighter in ready:
		if restarting or not active or not battle.battle_running or not player.is_alive():
			break
		if not is_instance_valid(fighter) or not fighter.is_alive():
			continue
		var slot: MonsterSlot = slots_by_fighter[fighter]
		var healer := slot as HealerSlot
		var guard := slot as GuardSlot
		var spirit := slot as SpiritSlot
		var next_counter := slot.repeat_attack_counter
		if healer != null:
			await _play_group_heal(fighter, healer)
		elif spirit != null:
			await _cast_cold_weakness(fighter, spirit)
		elif guard != null and guards[fighter].preparing:
			next_counter = await _cast_guard(fighter, guard)
		else:
			if not attacked:
				shield += _draft_guard()
			attacked = true
			await _play_attack_motion(fighter, slot)
			if guard != null and fighter.is_alive() and _has_protection_target(fighter):
				guards[fighter].preparing = true
				next_counter = guard.shield_counter
		if is_instance_valid(fighter) and fighter.is_alive():
			attack_counters[fighter] = next_counter
			_update_action_previews()
	if attacked:
		weaken = 0.0
		shield = 0
	if cold_turns > 0 and not cold_refreshed:
		cold_turns -= 1
		if cold_turns > 0:
			battle.left_status_effects.set_effect(cold_weakness, cold_turns)
		else:
			_clear_cold_weakness()


func _play_attack_motion(fighter: Fighter, slot: MonsterSlot) -> void:
	var sprite := fighter.character_sprite
	var start := sprite.position
	var start_rotation := sprite.rotation
	var span := formation_visual.sprite_span(fighter.character_data, 1.0)
	var direction := fighter.to_local(player.character_sprite.global_position) - start
	var travel := direction.normalized() * (span.y - span.x) * slot.lunge_width_ratio
	var pivot := fighter.character_data.sprite_size * slot.attack_pivot_ratio
	if sprite.flip_h:
		pivot.x = -pivot.x
	var facing := signf(direction.x)
	var windup := Vector3(0.0, 0.0, -facing * deg_to_rad(slot.windup_degrees))
	var strike := Vector3(travel.x, travel.y, facing * deg_to_rad(slot.strike_degrees))
	var apply_pose := func(pose: Vector3) -> void:
		sprite.rotation = start_rotation + pose.z
		sprite.position = start + Vector2(pose.x, pose.y) + pivot.rotated(start_rotation) - pivot.rotated(sprite.rotation)
	var motion := fighter.create_tween().set_ignore_time_scale(true)
	if slot.windup_seconds > 0.0:
		motion.tween_method(apply_pose, Vector3.ZERO, windup, slot.windup_seconds).set_trans(Tween.TRANS_QUAD)
	else:
		windup = Vector3.ZERO
	motion.tween_method(apply_pose, windup, strike, slot.lunge_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_callback(_hit_player.bind(fighter))
	motion.tween_method(apply_pose, strike, Vector3.ZERO, slot.return_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await motion.finished


func _hit_player(fighter: Fighter) -> void:
	if restarting or not active or not battle.battle_running or not fighter.is_alive() or not player.is_alive():
		return
	var damage_multiplier := cold_weakness.incoming_damage_multiplier if cold_turns > 0 else 1.0
	var attack := roundi(fighter.attack_power * (1.0 - weaken) * damage_multiplier)
	var damage := mini(player.current_health, maxi(0, attack - shield - _enemy_attack_reduction()))
	shield = maxi(0, shield - attack)
	if damage > 0:
		turn_attack_visual.show_impact(player, damage, damage >= player.current_health, false)
		player.take_damage(damage)


func _enemy_attack_reduction() -> int:
	return 0


func _play_group_heal(caster: Fighter, slot: HealerSlot) -> void:
	var targets: Array[Fighter] = []
	for ally in front + rear:
		if is_instance_valid(ally) and ally != caster and ally.is_alive() and ally.current_health < ally.max_health:
			targets.append(ally)
	if targets.is_empty():
		return
	var sprite := caster.character_sprite
	var base_scale := sprite.scale
	var span := formation_visual.sprite_span(caster.character_data, caster.base_scale.x)
	var glow := heal_visual.add_glow(sprite.global_position, (span.y - span.x) * 1.75)
	var motion := caster.create_tween().set_ignore_time_scale(true)
	motion.tween_property(sprite, "scale", base_scale * slot.cast_scale, slot.swell_seconds)
	motion.parallel().tween_property(glow, "modulate:a", 0.85, slot.swell_seconds)
	motion.tween_callback(_heal_allies.bind(caster, targets, slot.heal_amount))
	motion.tween_property(sprite, "scale", base_scale, slot.settle_seconds)
	motion.parallel().tween_property(glow, "modulate:a", 0.0, slot.settle_seconds)
	motion.tween_callback(glow.queue_free)
	await motion.finished


func _heal_allies(caster: Fighter, targets: Array[Fighter], amount: int) -> void:
	if restarting or not active or not battle.battle_running or not caster.is_alive():
		return
	var total := 0
	for ally in targets:
		if not is_instance_valid(ally) or not ally.is_alive():
			continue
		var recovered := mini(amount, ally.max_health - ally.current_health)
		if recovered <= 0:
			continue
		ally.heal(recovered)
		heal_visual.show_recovery(ally.character_sprite.global_position, recovered, total == 0)
		total += recovered
	# Settlement tracks the visible formation's combined HP on the shared enemy.
	enemy.heal(total)


func _start_spirit_hover(fighter: Fighter, slot: SpiritSlot) -> void:
	var sprite := fighter.character_sprite
	var center := sprite.position.y
	var amplitude := slot.character.sprite_size.y * slot.hover_height_ratio
	var motion := fighter.create_tween().set_loops()
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(sprite, "position:y", center - amplitude, slot.hover_period * 0.25)
	motion.tween_property(sprite, "position:y", center + amplitude, slot.hover_period * 0.5)
	motion.tween_property(sprite, "position:y", center, slot.hover_period * 0.25)
	spirit_hover[fighter] = motion


func _cast_cold_weakness(caster: Fighter, slot: SpiritSlot) -> void:
	var sprite := caster.character_sprite
	var base_scale := sprite.scale
	var span := formation_visual.sprite_span(caster.character_data, caster.base_scale.x)
	var glow := heal_visual.add_glow(sprite.global_position, (span.y - span.x) * 1.8, Color("#68cdff"))
	var motion := caster.create_tween().set_ignore_time_scale(true)
	motion.tween_property(sprite, "scale", base_scale * slot.cast_scale, slot.swell_seconds)
	motion.parallel().tween_property(glow, "modulate:a", 0.85, slot.swell_seconds)
	motion.tween_callback(_apply_cold_weakness.bind(caster, slot))
	motion.tween_property(sprite, "scale", base_scale, slot.settle_seconds)
	motion.parallel().tween_property(glow, "modulate:a", 0.0, slot.settle_seconds)
	motion.tween_callback(glow.queue_free)
	await motion.finished


func _apply_cold_weakness(caster: Fighter, slot: SpiritSlot) -> void:
	if restarting or not active or not battle.battle_running or not caster.is_alive() or not player.is_alive():
		return
	cold_turns = slot.weakness_duration
	cold_refreshed = true
	cold_weakness.incoming_damage_multiplier = 1.0 + slot.incoming_damage_bonus
	cold_weakness.display_name = "냉기 쇠약 · 몬스터 공격 피해 +%d%%" % roundi(slot.incoming_damage_bonus * 100.0)
	battle.left_status_effects.set_effect(cold_weakness, cold_turns)
	_guard_glow(player, 0.30)


func _clear_cold_weakness() -> void:
	cold_turns = 0
	battle.left_status_effects.remove_effect(cold_weakness.effect_id)


func _clear_spirit_hover() -> void:
	for motion: Tween in spirit_hover.values():
		motion.kill()
	spirit_hover.clear()


func _on_player_defeated(_fighter: Fighter) -> void:
	_clear_cold_weakness()


func _advance_guard_protection(fighter: Fighter) -> bool:
	var state := guards[fighter]
	if state.reset_this_turn:
		state.reset_this_turn = false
		return true
	if is_instance_valid(state.target):
		attack_counters[fighter] -= 1
		if attack_counters[fighter] == 0:
			_end_guard(fighter)
		else:
			_protection_bar(state.target).set_effect(protection_effect, attack_counters[fighter])
		return true
	if state.preparing and not _has_protection_target(fighter):
		_end_guard(fighter)
		return true
	return false


func _can_protect(fighter: Fighter, target: Fighter) -> bool:
	if not is_instance_valid(target) or fighter == target or not target.is_alive() or target.is_queued_for_deletion():
		return false
	for state: GuardState in guards.values():
		if state.target == target:
			return false
	return true


func _has_protection_target(fighter: Fighter) -> bool:
	for target in fighters_in_wave:
		if _can_protect(fighter, target):
			return true
	return false


func _pick_protection_target(fighter: Fighter, slot: GuardSlot) -> Fighter:
	var state := guards[fighter]
	for step in range(slot.protection_order.size()):
		var order_index := (state.order_index + step) % slot.protection_order.size()
		var index := slot.protection_order[order_index] - 1
		if index < 0 or index >= fighters_in_wave.size():
			continue
		var target := fighters_in_wave[index]
		if _can_protect(fighter, target):
			if slot.rotate_protection_order:
				state.order_index = (order_index + 1) % slot.protection_order.size()
			return target
	for target in fighters_in_wave:
		if _can_protect(fighter, target):
			return target
	return null


func _cast_guard(fighter: Fighter, slot: GuardSlot) -> int:
	var target := _pick_protection_target(fighter, slot)
	guards[fighter].preparing = false
	if target == null:
		return slot.repeat_attack_counter
	_guard_glow(fighter, 0.35)
	await get_tree().create_timer(0.15, false, false, true).timeout
	if restarting or not active or not battle.battle_running or not fighter.is_alive() or not _can_protect(fighter, target):
		return slot.repeat_attack_counter
	guards[fighter].target = target
	_protection_bar(target).set_effect(protection_effect, slot.shield_duration)
	_guard_glow(target, 0.30)
	_update_action_previews()
	await get_tree().create_timer(0.20, false, false, true).timeout
	return slot.shield_duration


func _guard_glow(fighter: Fighter, duration: float) -> void:
	var span := formation_visual.sprite_span(fighter.character_data, fighter.base_scale.x)
	var glow := heal_visual.add_glow(fighter.character_sprite.global_position, (span.y - span.x) * 1.8, Color("#68cdff"))
	glow.modulate.a = 0.92
	var tween := glow.create_tween().set_ignore_time_scale(true)
	tween.tween_property(glow, "modulate:a", 0.0, duration)
	tween.tween_callback(glow.queue_free)


func _protection_bar(target: Fighter) -> StatusEffectBar:
	var bar: WaterHealthBar = target.get_meta("formation_info")
	return bar.get_node("Effects") as StatusEffectBar


func _get_damage_redirects(roster: Array[Fighter]) -> Dictionary[int, int]:
	var redirects: Dictionary[int, int] = {}
	for fighter in guards:
		var target: Fighter = guards[fighter].target
		if not is_instance_valid(fighter) or not fighter.is_alive() or not is_instance_valid(target) or not target.is_alive():
			continue
		var source_index := roster.find(fighter)
		var target_index := roster.find(target)
		if source_index >= 0 and target_index >= 0:
			redirects[target_index] = source_index
	return redirects


func _on_damage_redirected(target: Fighter) -> void:
	_guard_glow(target, 0.22)


func _on_formation_fighter_defeated(fighter: Fighter) -> void:
	if spirit_hover.has(fighter):
		spirit_hover[fighter].kill()
		spirit_hover.erase(fighter)
	var index := fighters_in_wave.find(fighter)
	if index >= 0:
		fighters_in_wave[index] = null
	if guards.has(fighter):
		_end_guard(fighter)
		guards.erase(fighter)
	for guardian in guards:
		if guards[guardian].target == fighter:
			_end_guard(guardian)
			guards[guardian].reset_this_turn = true
	attack_counters.erase(fighter)
	slots_by_fighter.erase(fighter)
	if cold_turns > 0 and not fighters_in_wave.any(
		func(ally: Fighter) -> bool: return is_instance_valid(ally) and ally.is_alive()
	):
		_clear_cold_weakness()


func _end_guard(fighter: Fighter) -> void:
	var state := guards[fighter]
	if is_instance_valid(state.target):
		_protection_bar(state.target).remove_effect(Protection.effect_id)
	state.target = null
	state.preparing = false
	var slot: GuardSlot = slots_by_fighter[fighter]
	attack_counters[fighter] = slot.repeat_attack_counter
	_update_action_previews()


func _clear_guards() -> void:
	for fighter in guards:
		_end_guard(fighter)
	guards.clear()


func _on_cleanup() -> void:
	player.defeated.disconnect(_on_player_defeated)
	_clear_cold_weakness()
	_clear_spirit_hover()
	_clear_guards()
	super._on_cleanup()


func _update_action_previews() -> void:
	for fighter in front + rear:
		if is_instance_valid(fighter) and fighter.is_alive() and attack_counters.has(fighter):
			var healer := slots_by_fighter[fighter] as HealerSlot
			if healer != null:
				formation_visual.set_action_preview(fighter, ActionIcons.Kind.HEAL,
					attack_counters[fighter], false, healer.heal_amount)
			elif slots_by_fighter[fighter] is SpiritSlot:
				formation_visual.set_action_preview(fighter, ActionIcons.Kind.SKILL,
					attack_counters[fighter], false, 0, true, cold_weakness.icon)
			elif guards.has(fighter) and is_instance_valid(guards[fighter].target):
				formation_visual.set_action_preview(fighter, ActionIcons.Kind.SHIELD, -1, false, 0, false)
			elif guards.has(fighter) and guards[fighter].preparing:
				formation_visual.set_action_preview(fighter, ActionIcons.Kind.SHIELD, attack_counters[fighter])
			else:
				formation_visual.set_action_preview(fighter, ActionIcons.Kind.ATTACK, attack_counters[fighter])
