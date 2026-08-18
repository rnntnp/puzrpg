class_name MergeDrivenTerrainHandler
extends TestGimmickHandler

enum DeviceMode {
	SHELF,
	DIVIDER,
}

var tuning: MergeDrivenTerrainConfig
var overlay: MergeDrivenTerrainOverlay
var enemy_mode := 0
var active_mode := DeviceMode.SHELF
var mode_turns_remaining := -1
var attack_turns_remaining := 0
var shelf_index := 1
var divider_index := 1
var left_merges := 0
var right_merges := 0
var suppress_device_input := false
var collecting_turn_input := false
var movement_direction := 0
var shelf_body: AnimatableBody2D
var divider_body: AnimatableBody2D
var shelf_size := Vector2.ZERO
var divider_size := Vector2.ZERO


func _on_configured() -> void:
	tuning = data.tuning as MergeDrivenTerrainConfig
	if tuning == null:
		tuning = MergeDrivenTerrainConfig.new()
	overlay = attach_visual_layer(MergeDrivenTerrainOverlay.new()) as MergeDrivenTerrainOverlay
	attack_turns_remaining = data.normal_attack_interval
	_configure_enemy_mode(true)


func _on_enemy_changed() -> void:
	left_merges = 0
	right_merges = 0
	suppress_device_input = false
	collecting_turn_input = false
	movement_direction = 0
	attack_turns_remaining = data.normal_attack_interval
	_configure_enemy_mode(false)


func _configure_enemy_mode(first_enemy: bool) -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	if enemy_mode == 0:
		active_mode = DeviceMode.SHELF
		mode_turns_remaining = -1
		_set_device_presence(true, false)
	elif enemy_mode == 1:
		active_mode = DeviceMode.DIVIDER
		mode_turns_remaining = -1
		_set_device_presence(false, true)
	else:
		active_mode = DeviceMode.SHELF
		mode_turns_remaining = tuning.boss_mode_switch_turns
		_set_device_presence(true, true)
	if first_enemy:
		shelf_index = 1
		divider_index = 1
	_update_device_positions()
	_update_overlay()
	_update_ui()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	merge_game.set_input_enabled(false)
	var left_count: int = left_merges
	var right_count: int = right_merges
	left_merges = 0
	right_merges = 0
	var dominant_side: int = 0
	if left_count > right_count:
		dominant_side = -1
	elif right_count > left_count:
		dominant_side = 1
	suppress_device_input = true
	collecting_turn_input = false
	if dominant_side != 0:
		await _move_active_device(dominant_side)
	if active and is_instance_valid(merge_game):
		await merge_game.wait_until_board_settled(tuning.settle_timeout)
	movement_direction = 0
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	_advance_normal_attack()
	if not player.is_alive():
		busy = false
		return
	if enemy_mode == 2:
		mode_turns_remaining = maxi(0, mode_turns_remaining - 1)
		if mode_turns_remaining <= 0:
			active_mode = DeviceMode.DIVIDER if active_mode == DeviceMode.SHELF else DeviceMode.SHELF
			mode_turns_remaining = tuning.boss_mode_switch_turns
			battle.status_label.text = "장치 모드 전환: %s" % _mode_name()
			battle.status_label.modulate = Color("#ffd166")
			log_event("MODE CHANGED", _mode_name())
	merge_game.set_input_enabled(true)
	busy = false
	_update_overlay()
	_update_ui()


func _on_merge_registered(_result: int, origin: Vector2, _chain: int, _sources: Array[int], _cursed: bool) -> void:
	if not active or suppress_device_input or not collecting_turn_input:
		return
	if origin.x < merge_game.get_base_board_bounds().get_center().x:
		left_merges += 1
	else:
		right_merges += 1
	_update_overlay()


func _on_player_ball_dropped() -> void:
	if not active or busy or not enemy.is_alive():
		return
	left_merges = 0
	right_merges = 0
	suppress_device_input = false
	collecting_turn_input = true
	_update_overlay()
	_update_ui()


func _move_active_device(dominant_side: int) -> void:
	var target_index: int
	var body: AnimatableBody2D
	if active_mode == DeviceMode.SHELF:
		target_index = clampi(shelf_index + dominant_side, 0, 2)
		body = shelf_body
	else:
		target_index = clampi(divider_index - dominant_side, 0, 2)
		body = divider_body
	var current_index: int = shelf_index if active_mode == DeviceMode.SHELF else divider_index
	if target_index == current_index or not is_instance_valid(body):
		log_event("DEVICE HOLD", "%s index=%d" % [_mode_name(), current_index])
		return
	movement_direction = 1 if target_index > current_index else -1
	_update_overlay()
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	var target_x: float = _device_x(target_index, active_mode)
	var tween: Tween = create_gimmick_tween()
	tween.tween_property(body, "position:x", target_x, tuning.movement_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if active_mode == DeviceMode.SHELF:
		shelf_index = target_index
	else:
		divider_index = target_index
	_update_overlay()
	log_event("DEVICE MOVED", "%s index=%d" % [_mode_name(), target_index])


func _advance_normal_attack() -> void:
	attack_turns_remaining = maxi(0, attack_turns_remaining - 1)
	if attack_turns_remaining <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		attack_turns_remaining = data.normal_attack_interval


func _set_device_presence(show_shelf: bool, show_divider: bool) -> void:
	if show_shelf and not is_instance_valid(shelf_body):
		shelf_body = _create_shelf()
	elif not show_shelf:
		_remove_device(shelf_body)
		shelf_body = null
	if show_divider and not is_instance_valid(divider_body):
		divider_body = _create_divider()
	elif not show_divider:
		_remove_device(divider_body)
		divider_body = null


func _create_shelf() -> AnimatableBody2D:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	shelf_size = Vector2(bounds.size.x * tuning.shelf_width_ratio, tuning.shelf_thickness)
	var body: AnimatableBody2D = AnimatableBody2D.new()
	body.name = "MergeDrivenShelf"
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group(&"drop_landing_surface")
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = shelf_size
	collision.shape = shape
	collision.one_way_collision = true
	collision.one_way_collision_margin = tuning.shelf_one_way_margin
	body.add_child(collision)
	merge_game.gimmick_objects.add_child(body)
	return body


func _create_divider() -> AnimatableBody2D:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	divider_size = Vector2(tuning.divider_thickness, bounds.size.y * tuning.divider_height_ratio)
	var body: AnimatableBody2D = AnimatableBody2D.new()
	body.name = "MergeDrivenDivider"
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 1
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = divider_size
	collision.shape = shape
	body.add_child(collision)
	merge_game.gimmick_objects.add_child(body)
	return body


func _update_device_positions() -> void:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	if is_instance_valid(shelf_body):
		shelf_body.position = Vector2(
			_device_x(shelf_index, DeviceMode.SHELF),
			bounds.position.y + bounds.size.y * tuning.shelf_height_ratio
		)
	if is_instance_valid(divider_body):
		divider_body.position = Vector2(
			_device_x(divider_index, DeviceMode.DIVIDER),
			bounds.end.y - divider_size.y * 0.5
		)


func _device_x(index: int, mode: int) -> float:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var ratio: float
	if mode == DeviceMode.SHELF:
		match clampi(index, 0, 2):
			0: ratio = 1.0 / 6.0
			1: ratio = 0.5
			_: ratio = 5.0 / 6.0
	else:
		match clampi(index, 0, 2):
			0: ratio = 1.0 / 3.0
			1: ratio = 0.5
			_: ratio = 2.0 / 3.0
	return bounds.position.x + bounds.size.x * ratio


func _update_overlay() -> void:
	if not is_instance_valid(overlay):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		shelf_body.position if is_instance_valid(shelf_body) else Vector2.ZERO,
		shelf_size,
		divider_body.position if is_instance_valid(divider_body) else Vector2.ZERO,
		divider_size,
		is_instance_valid(shelf_body),
		is_instance_valid(divider_body),
		active_mode,
		mode_turns_remaining if enemy_mode == 2 else -1,
		left_merges,
		right_merges,
		movement_direction
	)


func _update_ui() -> void:
	var primary: String = "%s · %s" % [_mode_name(), _position_name(shelf_index if active_mode == DeviceMode.SHELF else divider_index)]
	if enemy_mode == 2:
		primary = "%s · %d턴" % [_mode_name(), mode_turns_remaining]
	var detail: String = "LEFT %d | RIGHT %d · 일반 공격 %d턴" % [left_merges, right_merges, attack_turns_remaining]
	battle.update_gimmick_ui(primary, detail)


func _mode_name() -> String:
	return "SHELF MODE" if active_mode == DeviceMode.SHELF else "DIVIDER MODE"


func _position_name(index: int) -> String:
	match clampi(index, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"


func _remove_device(body: AnimatableBody2D) -> void:
	if not is_instance_valid(body):
		return
	if body.get_parent() != null:
		body.get_parent().remove_child(body)
	body.queue_free()


func _on_cleanup() -> void:
	_remove_device(shelf_body)
	_remove_device(divider_body)
	shelf_body = null
	divider_body = null
	left_merges = 0
	right_merges = 0
	suppress_device_input = false
	collecting_turn_input = false
