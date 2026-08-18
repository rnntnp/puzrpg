class_name BoardIntrusionHandler
extends TestGimmickHandler

const SIDE_LEFT := -1
const SIDE_RIGHT := 1
const HEIGHT_LOW := 0
const HEIGHT_HIGH := 1

var tuning: BoardIntrusionConfig
var overlay: BoardIntrusionOverlay
var enemy_mode := 0
var pattern_index := 0
var telegraph_remaining := 0
var hold_remaining := 0
var arms_active := false
var arm_specs: Array[Vector2i] = []
var arm_bodies: Array[AnimatableBody2D] = []
var arm_size := Vector2.ZERO
var result_text := ""
var normal_attack_turns := 0


func _on_configured() -> void:
	tuning = data.tuning as BoardIntrusionConfig
	if tuning == null:
		tuning = BoardIntrusionConfig.new()
	overlay = attach_visual_layer(BoardIntrusionOverlay.new()) as BoardIntrusionOverlay
	_configure_enemy()


func _on_enemy_changed() -> void:
	_remove_arms()
	result_text = ""
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	pattern_index = 0
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	arm_size = Vector2(bounds.size.x * tuning.arm_length_ratio, bounds.size.y * tuning.arm_thickness_ratio)
	arms_active = false
	hold_remaining = 0
	telegraph_remaining = tuning.telegraph_turns
	arm_specs = _pattern_at(pattern_index)
	normal_attack_turns = data.normal_attack_interval
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	busy = true
	if arms_active:
		hold_remaining = maxi(0, hold_remaining - 1)
		if hold_remaining <= 0:
			merge_game.set_input_enabled(false)
			await _retract_arms()
			if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
				busy = false
				return
			pattern_index += 1
			arm_specs = _pattern_at(pattern_index)
			telegraph_remaining = tuning.telegraph_turns
			result_text = "NEXT INTRUSION READY"
			merge_game.set_input_enabled(true)
	else:
		telegraph_remaining = maxi(0, telegraph_remaining - 1)
		if telegraph_remaining <= 0:
			merge_game.set_input_enabled(false)
			await _enter_arms()
			if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
				busy = false
				return
			merge_game.set_input_enabled(true)
	_advance_normal_attack()
	if not player.is_alive():
		busy = false
		return
	busy = false
	_update_feedback()


func _enter_arms() -> void:
	_remove_arms()
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	arm_size = Vector2(bounds.size.x * tuning.arm_length_ratio, bounds.size.y * tuning.arm_thickness_ratio)
	var tween: Tween = create_gimmick_tween()
	tween.set_parallel(true)
	for spec in arm_specs:
		var body: AnimatableBody2D = _create_arm(spec)
		arm_bodies.append(body)
		tween.tween_property(body, "position:x", _target_x(spec.x), tuning.movement_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	result_text = "ARM INTRUSION"
	_update_feedback()
	await tween.finished
	arms_active = true
	hold_remaining = tuning.hold_turns
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	log_event("ARMS ENTERED", _specs_text())


func _retract_arms() -> void:
	if arm_bodies.is_empty():
		arms_active = false
		return
	var tween: Tween = create_gimmick_tween()
	tween.set_parallel(true)
	for arm_index in arm_bodies.size():
		var body: AnimatableBody2D = arm_bodies[arm_index]
		if is_instance_valid(body):
			tween.tween_property(body, "position:x", _outside_x(arm_specs[arm_index].x), tuning.movement_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	merge_game.suppress_danger_line(tuning.movement_duration + tuning.settle_timeout)
	result_text = "ARMS RETRACT"
	_update_feedback()
	await tween.finished
	_remove_arms()
	await merge_game.wait_until_board_settled(tuning.settle_timeout)
	log_event("ARMS RETRACTED", "pattern=%d" % pattern_index)


func _create_arm(spec: Vector2i) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = "LeftIntrusionArm" if spec.x == SIDE_LEFT else "RightIntrusionArm"
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector2(_outside_x(spec.x), _height_y(spec.y))
	body.add_to_group(&"drop_landing_surface")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = arm_size
	collision.shape = shape
	body.add_child(collision)
	merge_game.gimmick_objects.add_child(body)
	return body


func _pattern_at(index: int) -> Array[Vector2i]:
	var pattern: Array[Vector2i] = []
	if enemy_mode == 0:
		pattern.append(Vector2i(SIDE_LEFT if index % 2 == 0 else SIDE_RIGHT, HEIGHT_LOW))
	elif enemy_mode == 1:
		var sequence: Array[Vector2i] = [
			Vector2i(SIDE_LEFT, HEIGHT_LOW),
			Vector2i(SIDE_RIGHT, HEIGHT_HIGH),
			Vector2i(SIDE_RIGHT, HEIGHT_LOW),
			Vector2i(SIDE_LEFT, HEIGHT_HIGH),
		]
		pattern.append(sequence[index % sequence.size()])
	elif index % 2 == 0:
		pattern.append(Vector2i(SIDE_LEFT, HEIGHT_HIGH))
		pattern.append(Vector2i(SIDE_RIGHT, HEIGHT_LOW))
	else:
		pattern.append(Vector2i(SIDE_LEFT, HEIGHT_LOW))
		pattern.append(Vector2i(SIDE_RIGHT, HEIGHT_HIGH))
	return pattern


func _target_x(side: int) -> float:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	return bounds.position.x + arm_size.x * 0.5 if side == SIDE_LEFT else bounds.end.x - arm_size.x * 0.5


func _outside_x(side: int) -> float:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	return bounds.position.x - arm_size.x * 0.5 - 6.0 if side == SIDE_LEFT else bounds.end.x + arm_size.x * 0.5 + 6.0


func _height_y(height_mode: int) -> float:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var height_ratio: float = tuning.high_height_ratio if height_mode == HEIGHT_HIGH else tuning.low_height_ratio
	return bounds.end.y - bounds.size.y * height_ratio


func _specs_text() -> String:
	var entries: Array[String] = []
	for spec in arm_specs:
		entries.append("%s %s" % ["LEFT" if spec.x == SIDE_LEFT else "RIGHT", "HIGH" if spec.y == HEIGHT_HIGH else "LOW"])
	return " + ".join(entries)


func _advance_normal_attack() -> void:
	normal_attack_turns = maxi(0, normal_attack_turns - 1)
	if normal_attack_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		normal_attack_turns = data.normal_attack_interval


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game):
		return
	var body_positions: Array[Vector2] = []
	for body in arm_bodies:
		if is_instance_valid(body):
			body_positions.append(body.position)
	var target_centers: Array[Vector2] = []
	for spec in arm_specs:
		target_centers.append(Vector2(_target_x(spec.x), _height_y(spec.y)))
	overlay.show_state(merge_game.get_base_board_bounds(), arm_specs, target_centers, body_positions, arm_size, arms_active, telegraph_remaining, hold_remaining, result_text)
	if arms_active:
		battle.update_gimmick_ui("ARMS ACTIVE · RETRACT %d턴" % hold_remaining, _specs_text())
	else:
		battle.update_gimmick_ui("NEXT INTRUSION · %d턴" % telegraph_remaining, _specs_text())


func _physics_process_gimmick(_delta: float) -> void:
	if not arm_bodies.is_empty():
		_update_feedback()


func _remove_arms() -> void:
	for body in arm_bodies:
		if not is_instance_valid(body):
			continue
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		body.queue_free()
	arm_bodies.clear()
	arms_active = false
	hold_remaining = 0


func _on_cleanup() -> void:
	_remove_arms()
	arm_specs.clear()
	result_text = ""
