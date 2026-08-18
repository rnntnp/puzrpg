class_name StageFilterBoardHandler
extends TestGimmickHandler

var remaining_turns := 0
var tuning: StageFilterBoardConfig
var overlay: StageFilterBoardOverlay
var filter_mode := 0
var platform_y := 0.0
var left_pass := 2
var right_pass := 2
var swapped := false
var change_turns := 0
var platforms: Array[StaticBody2D] = []
var platform_pass_stages: Array[int] = []
var ball_pass_state: Dictionary = {}


func _on_configured() -> void:
	tuning = data.tuning as StageFilterBoardConfig
	if tuning == null:
		tuning = StageFilterBoardConfig.new()
	overlay = attach_visual_layer(StageFilterBoardOverlay.new()) as StageFilterBoardOverlay
	var enemy_index: int = battle.current_enemy_index
	filter_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	swapped = false
	change_turns = tuning.swap_interval if filter_mode == 2 else -1
	remaining_turns = data.normal_attack_interval
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	platform_y = bounds.position.y + bounds.size.y * tuning.height_ratio
	var thickness: float = tuning.platform_thickness
	if filter_mode == 0:
		var rect: Rect2 = Rect2(Vector2(bounds.position.x, platform_y - thickness * 0.5), Vector2(bounds.size.x, thickness))
		platforms.append(merge_game.spawn_one_way_platform(rect, tuning.one_way_margin))
	else:
		var half_width: float = bounds.size.x * 0.5
		var left_rect: Rect2 = Rect2(Vector2(bounds.position.x, platform_y - thickness * 0.5), Vector2(half_width, thickness))
		var right_rect: Rect2 = Rect2(Vector2(bounds.position.x + half_width, platform_y - thickness * 0.5), Vector2(half_width, thickness))
		platforms.append(merge_game.spawn_one_way_platform(left_rect, tuning.one_way_margin))
		platforms.append(merge_game.spawn_one_way_platform(right_rect, tuning.one_way_margin))
	_apply_filter_state()
	_update_ui()


func _on_enemy_changed() -> void:
	var enemy_index: int = battle.current_enemy_index
	filter_mode = clampi(tuning.enemy_modes[enemy_index], 0, 2) if enemy_index < tuning.enemy_modes.size() else 2
	swapped = false
	change_turns = tuning.swap_interval if filter_mode == 2 else -1
	remaining_turns = data.normal_attack_interval
	_rebuild_platforms()
	_apply_filter_state()
	_update_ui()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	if filter_mode == 2:
		change_turns = maxi(0, change_turns - 1)
		if change_turns <= 0:
			swapped = not swapped
			change_turns = tuning.swap_interval
			_apply_filter_state()
			battle.status_label.text = "FILTER CHANGED"
			battle.status_label.modulate = Color("#ffd166")
			log_event("FILTER CHANGED", "left=1~%d right=1~%d" % [left_pass, right_pass])
	remaining_turns = maxi(0, remaining_turns - 1)
	if remaining_turns <= 0:
		enemy.attack_with_damage(player, data.normal_attack_damage)
		remaining_turns = data.normal_attack_interval
	_update_overlay()
	_update_ui()


func _physics_process_gimmick(_delta: float) -> void:
	_update_collisions()


func _apply_filter_state() -> void:
	if filter_mode == 0:
		left_pass = tuning.basic_pass_stage
		right_pass = left_pass
		platform_pass_stages.assign([left_pass])
	else:
		left_pass = tuning.right_pass_stage if swapped else tuning.left_pass_stage
		right_pass = tuning.left_pass_stage if swapped else tuning.right_pass_stage
		platform_pass_stages.assign([left_pass, right_pass])
	ball_pass_state.clear()
	_update_collisions()
	_update_overlay()


func _rebuild_platforms() -> void:
	for platform in platforms:
		if is_instance_valid(platform):
			for ball in valid_balls():
				ball.remove_collision_exception_with(platform)
			if platform.get_parent() != null:
				platform.get_parent().remove_child(platform)
			platform.queue_free()
	platforms.clear()
	platform_pass_stages.clear()
	ball_pass_state.clear()
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var thickness: float = tuning.platform_thickness
	if filter_mode == 0:
		var rect: Rect2 = Rect2(Vector2(bounds.position.x, platform_y - thickness * 0.5), Vector2(bounds.size.x, thickness))
		platforms.append(merge_game.spawn_one_way_platform(rect, tuning.one_way_margin))
	else:
		var half_width: float = bounds.size.x * 0.5
		var left_rect: Rect2 = Rect2(Vector2(bounds.position.x, platform_y - thickness * 0.5), Vector2(half_width, thickness))
		var right_rect: Rect2 = Rect2(Vector2(bounds.position.x + half_width, platform_y - thickness * 0.5), Vector2(half_width, thickness))
		platforms.append(merge_game.spawn_one_way_platform(left_rect, tuning.one_way_margin))
		platforms.append(merge_game.spawn_one_way_platform(right_rect, tuning.one_way_margin))


func _update_collisions() -> void:
	for ball in valid_balls():
		for index in platforms.size():
			var platform: StaticBody2D = platforms[index]
			if not is_instance_valid(platform) or index >= platform_pass_stages.size():
				continue
			var cache_key: Vector2i = Vector2i(ball.get_instance_id(), index)
			var can_pass: bool = ball.merge_level + 1 <= platform_pass_stages[index]
			if ball_pass_state.get(cache_key, null) == can_pass:
				continue
			if can_pass:
				ball.add_collision_exception_with(platform)
			else:
				ball.remove_collision_exception_with(platform)
			ball_pass_state[cache_key] = can_pass


func _update_overlay() -> void:
	overlay.show_filter(
		merge_game.get_base_board_bounds(),
		platform_y,
		left_pass,
		right_pass,
		filter_mode != 0,
		change_turns if filter_mode == 2 else -1
	)


func _update_ui() -> void:
	var primary: String = ""
	var detail: String = ""
	if filter_mode == 0:
		primary = "PASS: 1~%d" % left_pass
		detail = "일반 공격 · %d턴" % remaining_turns
	elif filter_mode == 1:
		primary = "LEFT 1~%d | RIGHT 1~%d" % [left_pass, right_pass]
		detail = "일반 공격 · %d턴" % remaining_turns
	else:
		primary = "FILTER CHANGE · %d" % change_turns
		var next_left: int = tuning.left_pass_stage if swapped else tuning.right_pass_stage
		var next_right: int = tuning.right_pass_stage if swapped else tuning.left_pass_stage
		detail = "L 1~%d | R 1~%d · NEXT L 1~%d | R 1~%d" % [left_pass, right_pass, next_left, next_right]
	battle.update_gimmick_ui(primary, detail)


func _on_cleanup() -> void:
	ball_pass_state.clear()
	platforms.clear()
	platform_pass_stages.clear()
