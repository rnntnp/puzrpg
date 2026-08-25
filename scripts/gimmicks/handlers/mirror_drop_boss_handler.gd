class_name MirrorDropBossHandler
extends TestGimmickHandler

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const MergeAttackEffectScene = preload("res://scenes/merge_attack_effect.tscn")
const PHASE_NORMAL := 0
const PHASE_MIRROR := 1

var tuning: MirrorDropBossConfig
var overlay: MirrorDropBossOverlay
var phase := PHASE_NORMAL
var turns_remaining := 0
var last_player_level := -1
var last_player_drop_x := 0.0
var player_drop_recorded := false
var mirror_combo := 0
var mirror_damage_total := 0
var result_text := ""
var mirror_action_active := false
var mirror_last_merge_msec := 0


func _on_configured() -> void:
	tuning = data.tuning as MirrorDropBossConfig
	if tuning == null:
		tuning = MirrorDropBossConfig.new()
	overlay = attach_visual_layer(MirrorDropBossOverlay.new()) as MirrorDropBossOverlay
	if not merge_game.external_merge_damage_requested.is_connected(_on_external_merge_damage_requested):
		merge_game.external_merge_damage_requested.connect(_on_external_merge_damage_requested)
	_enter_normal_phase()


func _on_player_ball_landed(level: int, drop_x: float) -> void:
	if not active or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	if merge_game.is_external_merge_window_active():
		return
	last_player_level = level
	last_player_drop_x = drop_x
	player_drop_recorded = true


func _on_player_ball_dropped() -> void:
	if not active or busy or phase != PHASE_MIRROR or merge_game.is_external_merge_window_active():
		return
	# ball_dropped is emitted before the queue advances, so these are the exact
	# clamped X and stage of the released player ball.
	last_player_level = merge_game.get_current_ball_level()
	last_player_drop_x = merge_game.aim_x
	player_drop_recorded = true
	# Mirror Phase is a strict player-one-drop / boss-one-drop exchange.
	# Lock immediately on release so first contact cannot reopen a second drop
	# while the player's merge result is still being settled.
	merge_game.set_input_enabled(false)
	_refresh_overlay()


func on_turn_completed() -> void:
	if not active or busy or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		return
	if phase == PHASE_NORMAL:
		turns_remaining = maxi(0, turns_remaining - 1)
		if turns_remaining > 0:
			_clear_recorded_drop()
			_update_feedback()
			return
		busy = true
		merge_game.set_input_enabled(false)
		if _battle_is_active():
			_enter_mirror_phase()
			await _wait_player_turn_return()
		_finish_boss_action()
		return

	busy = true
	merge_game.set_input_enabled(false)
	if player_drop_recorded:
		await _execute_mirror_drop(last_player_level, last_player_drop_x)
	else:
		result_text = "MIRROR DROP SKIPPED"
		log_event("MIRROR SKIPPED", "player landing was not recorded")
	if not _battle_is_active():
		busy = false
		return
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		_enter_normal_phase()
	await _wait_player_turn_return()
	_finish_boss_action()


func _finish_boss_action() -> void:
	_clear_recorded_drop()
	result_text = ""
	if _battle_is_active():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	busy = false
	_update_feedback()


func _clear_recorded_drop() -> void:
	player_drop_recorded = false
	last_player_level = -1
	mirror_action_active = false


func _wait_player_turn_return() -> void:
	if tuning.player_turn_return_delay > 0.0:
		await get_tree().create_timer(tuning.player_turn_return_delay, true, false, true).timeout


func _execute_mirror_drop(level: int, player_drop_x: float) -> void:
	debug_special_execution_count += 1
	mirror_combo = 0
	mirror_damage_total = 0
	result_text = ""
	mirror_action_active = true
	battle.status_label.text = "보스의 미러 드롭!"
	battle.status_label.modulate = Color("#8be9fd")
	_update_feedback()
	if tuning.mirror_drop_delay > 0.0:
		await get_tree().create_timer(tuning.mirror_drop_delay, true, false, true).timeout
	if not _battle_is_active():
		return
	var spawn_x := _mirror_x(player_drop_x, level)
	mirror_last_merge_msec = Time.get_ticks_msec()
	var external_merge_token := merge_game.begin_external_merge_window()
	var spawned: MergeBall = merge_game.spawn_gimmick_ball(
		level,
		Vector2(spawn_x, merge_game.drop_position_y),
		Vector2.ZERO,
		external_merge_token
	)
	if spawned == null:
		merge_game.end_external_merge_window()
		result_text = "MIRROR SPAWN FAILED"
		log_event("MIRROR SPAWN FAILED", "stage=%d x=%.1f" % [level + 1, spawn_x])
		_update_feedback()
		return
	log_event("MIRROR DROP", "stage=%d player_x=%.1f boss_x=%.1f" % [level + 1, player_drop_x, spawn_x])
	await _wait_for_mirror_resolution(spawned)
	merge_game.end_external_merge_window()
	if mirror_combo > 0:
		result_text = "BOSS COMBO ×%d · %d DAMAGE" % [mirror_combo, mirror_damage_total]
	else:
		result_text = ""
	mirror_action_active = false
	_update_feedback()


func _wait_for_mirror_resolution(ball: MergeBall) -> void:
	var started_msec := Time.get_ticks_msec()
	var quiet_msec := roundi(tuning.mirror_merge_quiet_time * 1000.0)
	var timeout_msec := roundi(tuning.mirror_resolution_timeout * 1000.0)
	while _battle_is_active():
		var now_msec := Time.get_ticks_msec()
		var has_landed := not is_instance_valid(ball) or ball.has_landed()
		var merge_is_quiet := now_msec - mirror_last_merge_msec >= quiet_msec
		if has_landed and merge_is_quiet:
			return
		if now_msec - started_msec >= timeout_msec:
			log_event("MIRROR RESOLUTION TIMEOUT", "timeout=%.2f" % tuning.mirror_resolution_timeout)
			return
		await get_tree().physics_frame


func _on_external_merge_damage_requested(
	normal_damage: int,
	combo_count: int,
	_base_points: int,
	origin: Vector2,
	ball_level: int
) -> void:
	if not active or not merge_game.is_external_merge_window_active():
		return
	mirror_last_merge_msec = Time.get_ticks_msec()
	mirror_combo = maxi(mirror_combo, combo_count)
	var scaled_damage := maxi(0, roundi(float(normal_damage) * tuning.mirror_damage_scale))
	if scaled_damage > 0 and is_instance_valid(player) and player.is_alive():
		_launch_mirror_projectile(origin, ball_level, scaled_damage, combo_count)
	log_event(
		"BOSS MERGE",
		"combo=%d normal=%d scale=%.2f player_damage=%d" % [combo_count, normal_damage, tuning.mirror_damage_scale, scaled_damage]
	)
	_update_feedback()


func _launch_mirror_projectile(
	origin: Vector2,
	ball_level: int,
	damage: int,
	combo_count: int
) -> void:
	var ball_data: Resource = BallCatalogClass.get_ball(ball_level)
	if ball_data == null or not is_instance_valid(battle):
		return
	var effect = MergeAttackEffectScene.instantiate()
	battle.add_child(effect)
	if is_instance_valid(enemy):
		enemy.play_cast_animation()
	effect.hit.connect(_on_mirror_projectile_hit)
	effect.play(merge_game.to_global(origin), player.global_position, ball_data, damage, combo_count)


func _on_mirror_projectile_hit(damage: int) -> void:
	if not _battle_is_active():
		return
	player.take_damage(damage)
	mirror_damage_total += damage
	battle.status_label.text = "미러 반격 · %d 피해" % damage
	battle.status_label.modulate = Color("#ff7b8b")
	_update_feedback()


func _enter_normal_phase() -> void:
	phase = PHASE_NORMAL
	turns_remaining = maxi(1, tuning.normal_phase_drops)
	mirror_combo = 0
	mirror_damage_total = 0
	result_text = ""
	mirror_action_active = false
	_update_feedback()


func _enter_mirror_phase() -> void:
	phase = PHASE_MIRROR
	turns_remaining = maxi(1, tuning.mirror_phase_drops)
	mirror_combo = 0
	mirror_damage_total = 0
	result_text = "MIRROR PHASE"
	mirror_action_active = false
	_update_feedback()


func _physics_process_gimmick(_delta: float) -> void:
	if phase == PHASE_MIRROR and not mirror_action_active:
		_refresh_overlay()


func _mirror_x(player_drop_x: float, level: int) -> float:
	var bounds: Rect2 = merge_game.get_board_inner_bounds()
	var ball_data: Resource = BallCatalogClass.get_ball(level)
	var radius := 26.0
	if ball_data != null:
		radius = maxf(radius, ball_data.get_radius())
	var reflected := bounds.position.x + bounds.end.x - player_drop_x
	return clampf(reflected, bounds.position.x + radius, bounds.end.x - radius)


func _refresh_overlay() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	var use_recorded_drop: bool = phase == PHASE_MIRROR and player_drop_recorded and last_player_level >= 0
	var level: int = last_player_level if use_recorded_drop else merge_game.get_current_ball_level()
	var source_x: float = last_player_drop_x if use_recorded_drop else merge_game.aim_x
	overlay.show_state(
		merge_game.get_board_inner_bounds(),
		phase,
		_mirror_x(source_x, level),
		merge_game.drop_position_y,
		mirror_action_active
	)


func _update_feedback() -> void:
	_refresh_overlay()
	if not is_instance_valid(battle):
		return
	if phase == PHASE_MIRROR:
		battle.update_gimmick_ui(
			"MIRROR PHASE · %d" % turns_remaining,
			"내 수 정산 후 보스가 같은 단계로 반대편에 응수 · 피해 ×%.2f" % tuning.mirror_damage_scale
		)
	else:
		battle.update_gimmick_ui(
			"MIRROR PHASE · %d" % turns_remaining,
			"반대편의 같은 단계 공을 비워 두세요"
		)


func _battle_is_active() -> bool:
	return (
		active
		and is_instance_valid(enemy)
		and enemy.is_alive()
		and is_instance_valid(player)
		and player.is_alive()
		and is_instance_valid(merge_game)
	)


func _on_cleanup() -> void:
	if is_instance_valid(merge_game):
		merge_game.end_external_merge_window()
		if merge_game.external_merge_damage_requested.is_connected(_on_external_merge_damage_requested):
			merge_game.external_merge_damage_requested.disconnect(_on_external_merge_damage_requested)
	player_drop_recorded = false
	last_player_level = -1
	mirror_combo = 0
	mirror_damage_total = 0
	result_text = ""
	mirror_action_active = false
