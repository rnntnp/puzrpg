class_name StackCoverLaserHandler
extends TestGimmickHandler

const DIRECTION_LEFT_TO_RIGHT := 1
const DIRECTION_RIGHT_TO_LEFT := -1

var tuning: StackCoverLaserConfig
var overlay: StackCoverLaserOverlay
var enemy_mode := 0
var attack_index := 0
var turns_remaining := 0
var direction := DIRECTION_LEFT_TO_RIGHT
var piercing := false
var cover_line_y := 0.0
var cover_states: Array[bool] = [false, false, false]
var flash_zones: Array[int] = []
var result_text := ""
var refresh_elapsed := 0.0


func _on_configured() -> void:
	tuning = data.tuning as StackCoverLaserConfig
	if tuning == null:
		tuning = StackCoverLaserConfig.new()
	overlay = attach_visual_layer(StackCoverLaserOverlay.new()) as StackCoverLaserOverlay
	_configure_enemy()
	_refresh_cover()


func _on_enemy_changed() -> void:
	flash_zones.clear()
	result_text = ""
	_configure_enemy()
	_refresh_cover()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	attack_index = 0
	turns_remaining = _attack_interval(enemy_index)
	_set_next_attack()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_refresh_cover()
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining <= 0:
		await _fire_laser()
		if not active or not enemy.is_alive() or not player.is_alive():
			busy = false
			return
		attack_index += 1
		turns_remaining = _attack_interval(battle.current_enemy_index)
		_set_next_attack()
		await merge_game.wait_until_board_settled(tuning.settle_timeout)
		_refresh_cover()
		flash_zones.clear()
		result_text = ""
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	merge_game.set_input_enabled(true)
	busy = false
	_update_feedback()


func _physics_process_gimmick(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 0.15:
		refresh_elapsed = 0.0
		_refresh_cover()


func _refresh_cover() -> void:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var danger_y: float = float(merge_game.danger_line_y)
	cover_line_y = lerpf(bounds.end.y, danger_y, tuning.cover_line_safe_height_ratio)
	for zone_index in 3:
		cover_states[zone_index] = false
	for ball in valid_balls():
		var zone_index: int = _zone_for_x(ball.position.x)
		if ball.position.y - ball.get_radius() <= cover_line_y:
			cover_states[zone_index] = true
	_update_feedback()


func _fire_laser() -> void:
	debug_special_execution_count += 1
	flash_zones.clear()
	var needed_covers: int = 2 if piercing else 1
	var absorbed := 0
	var ordered_zones: Array[int] = [0, 1, 2] if direction == DIRECTION_LEFT_TO_RIGHT else [2, 1, 0]
	for zone_index in ordered_zones:
		if not cover_states[zone_index]:
			continue
		var target: MergeBall = _top_ball_in_zone(zone_index)
		if target == null:
			continue
		absorbed += 1
		flash_zones.append(zone_index)
		_damage_cover_ball(target)
		result_text = "LASER HIT: %s" % _zone_name(zone_index)
		_update_feedback()
		if tuning.hit_interval > 0.0:
			await get_tree().create_timer(tuning.hit_interval, true, false, true).timeout
		if absorbed >= needed_covers:
			break
	if absorbed >= needed_covers:
		result_text = "LASER BLOCKED"
		battle.status_label.text = "레이저 차단!"
		battle.status_label.modulate = Color("#70ff9b")
	elif absorbed == 1 and piercing:
		var partial_damage: int = roundi(float(tuning.full_laser_damage) * tuning.partial_damage_ratio)
		enemy.attack_with_damage(player, partial_damage)
		result_text = "PIERCING PARTIAL · %d DAMAGE" % partial_damage
		battle.status_label.text = "관통 레이저 일부 피격"
		battle.status_label.modulate = Color("#ffb86c")
	else:
		enemy.attack_with_damage(player, tuning.full_laser_damage)
		result_text = "LASER UNBLOCKED · %d DAMAGE" % tuning.full_laser_damage
		battle.status_label.text = "레이저 직격!"
		battle.status_label.modulate = Color("#ff6b6b")
	log_event("LASER", "%s absorbed=%d" % ["PIERCING" if piercing else "NORMAL", absorbed])
	_update_feedback()


func _damage_cover_ball(target: MergeBall) -> void:
	if target.merge_level <= 0:
		merge_game.remove_gimmick_ball(target)
	else:
		merge_game.replace_ball_stage(target, target.merge_level - 1)


func _top_ball_in_zone(zone_index: int) -> MergeBall:
	var selected: MergeBall
	var selected_top := INF
	for ball in valid_balls():
		if _zone_for_x(ball.position.x) != zone_index:
			continue
		var ball_top: float = ball.position.y - ball.get_radius()
		if ball_top < selected_top:
			selected = ball
			selected_top = ball_top
	return selected


func _zone_for_x(x_value: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	return clampi(floori((x_value - bounds.position.x) / (bounds.size.x / 3.0)), 0, 2)


func _set_next_attack() -> void:
	if enemy_mode == 0:
		direction = DIRECTION_LEFT_TO_RIGHT
		piercing = false
	elif enemy_mode == 1:
		direction = DIRECTION_LEFT_TO_RIGHT if attack_index % 2 == 0 else DIRECTION_RIGHT_TO_LEFT
		piercing = false
	else:
		direction = DIRECTION_LEFT_TO_RIGHT if attack_index % 2 == 0 else DIRECTION_RIGHT_TO_LEFT
		piercing = attack_index % 2 == 1
	_update_feedback()


func _attack_interval(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < tuning.attack_intervals.size():
		return maxi(1, tuning.attack_intervals[enemy_index])
	return 4


func _zone_name(zone_index: int) -> String:
	if zone_index <= 0:
		return "LEFT"
	if zone_index == 1:
		return "CENTER"
	return "RIGHT"


func _direction_text() -> String:
	return "LEFT >>> RIGHT" if direction == DIRECTION_LEFT_TO_RIGHT else "RIGHT <<< LEFT"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	overlay.show_state(merge_game.get_base_board_bounds(), cover_line_y, cover_states, direction, piercing, turns_remaining, flash_zones, result_text)
	var type_text: String = "PIERCING" if piercing else "NORMAL"
	battle.update_gimmick_ui("%s · %s · %d턴" % [type_text, _direction_text(), turns_remaining], "COVER: %s | %s | %s" % [_cover_name(0), _cover_name(1), _cover_name(2)])


func _cover_name(zone_index: int) -> String:
	return "COVER" if cover_states[zone_index] else "OPEN"


func _on_cleanup() -> void:
	flash_zones.clear()
	result_text = ""
