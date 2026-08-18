class_name EnemyStanceHandler
extends TestGimmickHandler

var remaining_turns := 0
var tuning: EnemyStanceConfig
var overlay: EnemyStanceOverlay
var stance_mode := 0
var stance_side := 0
var left_merges := 0
var right_merges := 0
var damage_records: Array[Dictionary] = []


func _on_configured() -> void:
	tuning = data.tuning as EnemyStanceConfig
	if tuning == null:
		tuning = EnemyStanceConfig.new()
	overlay = attach_visual_layer(EnemyStanceOverlay.new()) as EnemyStanceOverlay
	var enemy_index: int = battle.current_enemy_index
	stance_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	stance_side = 0
	remaining_turns = data.action_interval
	_update_overlay()
	_update_ui()


func _on_enemy_changed() -> void:
	var enemy_index: int = battle.current_enemy_index
	stance_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	remaining_turns = data.action_interval
	left_merges = 0
	right_merges = 0
	damage_records.clear()
	_update_overlay()
	_update_ui()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	_finish_stance_turn()
	if stance_mode == 0:
		_update_ui()
		return
	remaining_turns = maxi(0, remaining_turns - 1)
	if remaining_turns > 0:
		_update_ui()
		return
	await _execute_attack()


func modify_player_damage(damage: int, _level := -1, _combo := 1, merge_origin := Vector2.ZERO) -> int:
	if not active or stance_mode not in [0, 2]:
		return damage
	var local_origin: Vector2 = merge_game.to_local(merge_origin)
	var record_index: int = -1
	var nearest_distance: float = INF
	for index in damage_records.size():
		var record_origin: Vector2 = damage_records[index].get("origin", Vector2.ZERO)
		var distance: float = record_origin.distance_squared_to(local_origin)
		if distance < nearest_distance:
			nearest_distance = distance
			record_index = index
	if record_index < 0:
		return damage
	var record: Dictionary = damage_records[record_index]
	damage_records.remove_at(record_index)
	var multiplier: float = float(record.get("multiplier", 1.0))
	var modified: int = maxi(1, roundi(float(damage) * multiplier))
	log_event("DAMAGE MODIFIER", "drop_stance=%s merge_side=%s multiplier=%.2f damage=%d->%d" % [record.get("stance"), record.get("side"), multiplier, damage, modified])
	return modified


func _on_merge_registered(_result: int, origin: Vector2, chain: int, _sources: Array[int], _cursed: bool) -> void:
	if not active:
		return
	var merge_side: int = _side_for_x(origin.x)
	if merge_side == 0:
		left_merges += 1
	else:
		right_merges += 1
	if stance_mode in [0, 2]:
		damage_records.append({
			"origin": origin,
			"multiplier": tuning.weak_multiplier if merge_side != stance_side else 1.0,
			"stance": _side_name(stance_side),
			"side": _side_name(merge_side),
		})
	log_event("STANCE MERGE", "side=%s chain=%d left=%d right=%d" % [_side_name(merge_side), chain, left_merges, right_merges])


func _finish_stance_turn() -> void:
	var previous: int = stance_side
	if left_merges > right_merges:
		stance_side = 0
	elif right_merges > left_merges:
		stance_side = 1
	left_merges = 0
	right_merges = 0
	_update_overlay()
	if previous != stance_side:
		battle.status_label.text = "STANCE CHANGED: %s" % _side_name(stance_side)
		battle.status_label.modulate = Color("#ffd166")
		log_event("STANCE CHANGED", "%s -> %s" % [_side_name(previous), _side_name(stance_side)])


func _execute_attack() -> void:
	busy = true
	debug_special_execution_count += 1
	merge_game.set_input_enabled(false)
	var candidates: Array[MergeBall] = []
	for ball in valid_balls():
		if _side_for_x(ball.position.x) == stance_side:
			candidates.append(ball)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool:
		return a.merge_level > b.merge_level if a.merge_level != b.merge_level else a.position.y < b.position.y
	)
	if not candidates.is_empty():
		var target: MergeBall = candidates.front() as MergeBall
		var old_stage: int = target.merge_level + 1
		target.modulate = Color("#ff6b6b")
		var tween: Tween = create_gimmick_tween()
		tween.tween_property(target, "modulate", Color.WHITE, 0.2)
		await tween.finished
		if is_instance_valid(target) and not target.merge_locked:
			var new_level: int = target.merge_level - tuning.stage_loss
			if new_level < 0:
				merge_game.remove_gimmick_ball(target)
			else:
				merge_game.replace_ball_stage(target, new_level)
			log_event("STANCE ATTACK", "%s stage=%d->%d" % [_side_name(stance_side), old_stage, maxi(0, new_level + 1)])
	else:
		log_event("STANCE ATTACK", "%s empty" % _side_name(stance_side))
	remaining_turns = data.action_interval
	await get_tree().create_timer(0.12, true, false, true).timeout
	if active and enemy.is_alive() and player.is_alive():
		merge_game.set_input_enabled(true)
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	busy = false
	_update_ui()


func _update_overlay() -> void:
	overlay.show_state(merge_game.get_base_board_bounds(), stance_side, stance_mode in [0, 2], stance_mode in [1, 2])


func _update_ui() -> void:
	var stance_name: String = _side_name(stance_side)
	var opposite_name: String = _side_name(1 - stance_side)
	var primary: String = "STANCE: %s %s" % [stance_name, ("←" if stance_side == 0 else "→")]
	var detail: String = ""
	match stance_mode:
		0: detail = "WEAK: %s · x%.2f" % [opposite_name, tuning.weak_multiplier]
		1: detail = "ATTACK: %s · %d턴" % [stance_name, remaining_turns]
		_: detail = "WEAK: %s · ATTACK: %s · %d턴" % [opposite_name, stance_name, remaining_turns]
	battle.update_gimmick_ui(primary, detail)


func _side_for_x(x_position: float) -> int:
	return 0 if x_position < merge_game.get_base_board_bounds().get_center().x else 1


func _side_name(side: int) -> String:
	return "LEFT" if side == 0 else "RIGHT"


func _on_cleanup() -> void:
	damage_records.clear()
