extends Node

const Pattern = preload("res://scripts/gimmicks/configs/ice_boss_pattern.gd")
const Freeze = preload("res://scripts/gimmicks/configs/ice_boss_freeze.gd")
const Projectile = preload("res://scenes/merge_attack_effect.tscn")
const AttackIntent = preload("res://resources/effects/enemy_attack_countdown.tres")
const FreezeIntent = preload("res://resources/effects/ice_countdown.tres")
const BurstIntent = preload("res://resources/effects/ice_burst_countdown.tres")

signal intent_changed(intent: StatusEffectData, counter: int)

enum Action { ATTACK, FREEZE, BURST }

class FrozenIce:
	var ball: MergeBall
	var caster: Fighter
	var cycle: int
	var kind: int
	var initial_durability: int
	var burst_damage: int
	var backlash_damage: int
	var burst_visual_scale: float

var host: TestGimmickHandler
var battle: Battle
var player: Fighter
var enemy: Fighter
var merge_game: MergeGame
var pattern: Pattern
var ice: IceSkillController
var current_freeze: Freeze
var normal_attack: Callable
var backlash_hit: Callable
var burst_hit: Callable
var counterattack_seconds := 0.0
var action := Action.ATTACK
var counter := 0
var freeze_cycle := 0
var frozen_ice: Array[FrozenIce] = []
var second_freeze_pending := false
var volley_in_progress := false
var board_space := RID()
var board_was_active := false


func configure(owner_handler: TestGimmickHandler, caster: Fighter, boss_pattern: Pattern,
	attack: Callable, backlash: Callable, attack_seconds: float, burst := Callable()) -> void:
	host = owner_handler
	battle = host.battle
	player = host.player
	enemy = caster
	merge_game = host.merge_game
	pattern = boss_pattern
	normal_attack = attack
	burst_hit = burst
	backlash_hit = backlash
	counterattack_seconds = attack_seconds
	ice = battle.monster_action_controller.ice_controller
	ice.ball_frozen.connect(_track_frozen_ice)
	enemy.defeated.connect(_on_boss_defeated)
	counter = pattern.initial_attack_turns
	_update_intent()


func advance_turn() -> void:
	if not _can_act():
		return
	counter -= 1
	if counter == 0:
		_update_intent()
		await _run_boss_action()
	if not _can_act():
		return
	if action == Action.FREEZE and counter == 1 and ice.begin_telegraph() > 0:
		enemy.show_ice_eye_glow()
	_update_intent()


func _update_intent() -> void:
	var intent: StatusEffectData = [AttackIntent, FreezeIntent, BurstIntent][action]
	intent_changed.emit(intent, counter)


func _can_act() -> bool:
	return host.active and not host.get("restarting") and battle.battle_running and enemy.is_alive() and player.is_alive()


func cleanup() -> void:
	_restore_board()
	if is_instance_valid(enemy):
		enemy.hide_ice_eye_glow()
		if enemy.defeated.is_connected(_on_boss_defeated):
			enemy.defeated.disconnect(_on_boss_defeated)
	if is_instance_valid(ice):
		ice.cancel_telegraph()
		if ice.ball_frozen.is_connected(_track_frozen_ice):
			ice.ball_frozen.disconnect(_track_frozen_ice)
	_clear_frozen_ice()


func _exit_tree() -> void:
	_restore_board()


func _run_boss_action() -> void:
	match action:
		Action.ATTACK:
			normal_attack.call()
			await get_tree().create_timer(counterattack_seconds, false, false, true).timeout
			if not _can_act():
				return
			freeze_cycle += 1
			second_freeze_pending = pattern.second_freeze != null
			_prepare_freeze(pattern.first_freeze, pattern.turns_before_freeze)
		Action.FREEZE:
			enemy.play_cast_animation()
			await ice.execute_telegraphed()
			enemy.hide_ice_eye_glow()
			if not _can_act():
				return
			if second_freeze_pending:
				second_freeze_pending = false
				_prepare_freeze(pattern.second_freeze, pattern.turns_between_freezes)
				return
			action = Action.BURST
			counter = pattern.burst_turns
		Action.BURST:
			_pause_board()
			enemy.show_ice_eye_glow()
			enemy.play_cast_animation()
			await get_tree().create_timer(0.2, false, false, true).timeout
			if _can_act():
				await _burst_remaining_ice()
			_restore_board()
			enemy.hide_ice_eye_glow()
			action = Action.ATTACK
			counter = pattern.turns_after_burst


func _prepare_freeze(profile: Freeze, delay: int) -> void:
	current_freeze = profile
	ice.configure(merge_game, profile, enemy)
	action = Action.FREEZE
	counter = delay


func _track_frozen_ice(ball: MergeBall) -> void:
	var entry := FrozenIce.new()
	entry.ball = ball
	entry.caster = enemy
	entry.cycle = freeze_cycle
	entry.kind = current_freeze.kind
	entry.initial_durability = ball.ice_durability
	entry.burst_damage = current_freeze.burst_damage
	entry.backlash_damage = current_freeze.backlash_damage
	entry.burst_visual_scale = current_freeze.burst_visual_scale
	frozen_ice.append(entry)


func _burst_remaining_ice() -> void:
	var charges: Array[FrozenIce] = []
	for entry in frozen_ice:
		if entry.cycle == freeze_cycle and is_instance_valid(entry.ball) and entry.ball.is_ice_frozen:
			charges.append(entry)
	if charges.is_empty():
		battle.update_gimmick_ui("", "폭발할 얼음 없음")
		await get_tree().create_timer(0.35, false, false, true).timeout
		_clear_frozen_ice()
		return

	var last_projectile: MergeAttackEffect
	var player_hits: Array[int] = []
	var boss_hits: Array[int] = []
	volley_in_progress = true
	for charge in charges:
		var ball := charge.ball
		var defused := ball.ice_durability == 0
		var target := charge.caster if defused else player
		var damage := charge.backlash_damage if defused else charge.burst_damage
		var color := Color("#73f4df") if defused else Color("#a8eaff")
		ball.play_ice_shatter_effect()
		var effect := Projectile.instantiate() as MergeAttackEffect
		add_child(effect)
		effect.hit.connect(_record_burst_hit.bind(defused, player_hits, boss_hits, charges.size()))
		effect.play(ball.global_position, target.character_sprite.global_position,
			BallCatalog.get_ball(ball.merge_level), damage, 1, color, charge.burst_visual_scale)
		last_projectile = effect
	await last_projectile.tree_exited
	volley_in_progress = false
	_clear_frozen_ice()


func _record_burst_hit(damage: int, defused: bool, player_hits: Array[int], boss_hits: Array[int], expected_hits: int) -> void:
	if not _can_act():
		return
	var hits := boss_hits if defused else player_hits
	hits.append(damage)
	if player_hits.size() + boss_hits.size() != expected_hits:
		return
	# Resolve the simultaneous volley through one result path if both sides would fall.
	if burst_hit.is_valid():
		burst_hit.call(player_hits)
	else:
		for hit in player_hits:
			player.take_damage(hit)
	for hit in boss_hits:
		if not player.is_alive() and hit >= enemy.current_health:
			break
		backlash_hit.call(hit)


func _clear_frozen_ice() -> void:
	for entry in frozen_ice:
		if is_instance_valid(entry.ball):
			entry.ball.break_ice(false)
	frozen_ice.clear()


func _on_boss_defeated(_fighter: Fighter) -> void:
	if not volley_in_progress:
		_clear_frozen_ice()


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


