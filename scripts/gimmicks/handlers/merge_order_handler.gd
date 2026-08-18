class_name MergeOrderHandler
extends TestGimmickHandler

const MergeOrderConfigClass = preload("res://scripts/gimmicks/configs/merge_order_config.gd")
const MergeOrderOverlayClass = preload("res://scripts/gimmicks/visuals/merge_order_overlay.gd")
const MODE_ZONE_ONLY := 0
const MODE_ZONE_AND_STAGE := 1
const MODE_ORDERED_ROUTE := 2

var tuning: MergeOrderConfigClass
var overlay: MergeOrderOverlayClass
var enemy_mode := MODE_ZONE_ONLY
var target_zone := 0
var target_result_stage := -1
var turns_remaining := 0
var route_progress := 0
var zone_pattern_index := 0
var stage_choice_index := 0
var awaiting_next_route_step := false
var pending_new_contract := false
var skip_next_turn_tick := false
var result_text := ""
var has_last_merge := false
var last_merge_origin := Vector2.ZERO
var last_merge_matched := false


func _on_configured() -> void:
	tuning = data.tuning as MergeOrderConfigClass
	if tuning == null:
		tuning = MergeOrderConfigClass.new()
	overlay = attach_visual_layer(MergeOrderOverlayClass.new()) as MergeOrderOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_ZONE_ONLY, MODE_ORDERED_ROUTE) if enemy_index < tuning.enemy_modes.size() else MODE_ORDERED_ROUTE
	zone_pattern_index = 0
	stage_choice_index = 0
	awaiting_next_route_step = false
	pending_new_contract = false
	skip_next_turn_tick = false
	result_text = ""
	has_last_merge = false
	last_merge_origin = Vector2.ZERO
	last_merge_matched = false
	_begin_contract()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	if skip_next_turn_tick:
		skip_next_turn_tick = false
		_update_feedback()
		return
	turns_remaining = maxi(0, turns_remaining - 1)
	if turns_remaining > 0:
		_update_feedback()
		return
	_resolve_failure()


func _on_player_ball_dropped() -> void:
	if not active:
		return
	result_text = ""
	has_last_merge = false
	if is_instance_valid(battle):
		battle.status_label.text = "BATTLE"
		battle.status_label.modulate = Color.WHITE
	_update_feedback()


func _on_merge_registered(
	result_level: int,
	origin: Vector2,
	_chain_index: int,
	_source_ids: Array[int],
	_involved_cursed: bool
) -> void:
	if not active or awaiting_next_route_step or not enemy.is_alive():
		return
	var result_stage: int = result_level + 1
	var merge_zone: int = _zone_for_x(origin.x)
	var matched: bool = merge_zone == target_zone and (target_result_stage < 0 or result_stage == target_result_stage)
	has_last_merge = true
	last_merge_origin = origin
	last_merge_matched = matched
	if not matched:
		result_text = "MISS · %s · STAGE %d" % [_zone_name(merge_zone), result_stage]
		log_event("ORDER MISS", "zone=%s stage=%d" % [_zone_name(merge_zone), result_stage])
		_update_feedback()
		return
	route_progress += 1
	if route_progress < _route_length():
		awaiting_next_route_step = true
		result_text = "ROUTE STEP %d/%d COMPLETE" % [route_progress, _route_length()]
		log_event("ROUTE STEP", "%d/%d" % [route_progress, _route_length()])
		_update_feedback()
		return
	_complete_contract()


func _on_merge_completed(_merged_ball: MergeBall) -> void:
	if not active or not awaiting_next_route_step or not enemy.is_alive():
		return
	awaiting_next_route_step = false
	if pending_new_contract:
		pending_new_contract = false
		_begin_contract()
	else:
		_set_next_requirement(target_zone)
	_update_feedback()


func _begin_contract() -> void:
	route_progress = 0
	awaiting_next_route_step = false
	turns_remaining = _turn_limit()
	_set_next_requirement(-1)
	_update_feedback()


func _set_next_requirement(previous_zone: int) -> void:
	target_zone = _next_pattern_zone(previous_zone)
	target_result_stage = -1 if enemy_mode == MODE_ZONE_ONLY else _choose_visible_result_stage()


func _next_pattern_zone(previous_zone: int) -> int:
	if tuning.zone_pattern.is_empty():
		var fallback_zone: int = zone_pattern_index % 3
		zone_pattern_index += 1
		return fallback_zone
	var attempts: int = maxi(3, tuning.zone_pattern.size())
	for _attempt in attempts:
		var candidate: int = clampi(int(tuning.zone_pattern[zone_pattern_index % tuning.zone_pattern.size()]), 0, 2)
		zone_pattern_index += 1
		if candidate != previous_zone:
			return candidate
	return (previous_zone + 1) % 3 if previous_zone >= 0 else 0


func _choose_visible_result_stage() -> int:
	var source_counts: Dictionary = {}
	for ball in valid_balls():
		_add_visible_source(source_counts, ball.merge_level)
	_add_visible_source(source_counts, merge_game.current_level)
	_add_visible_source(source_counts, merge_game.next_level)
	var candidates: Array[int] = []
	for source_key: Variant in source_counts.keys():
		var source_level: int = int(source_key)
		var visible_count: int = int(source_counts[source_key])
		var result_stage: int = source_level + 2
		if (
			visible_count >= 2
			and result_stage >= tuning.minimum_requested_result_stage
			and result_stage <= tuning.maximum_requested_result_stage
		):
			candidates.append(result_stage)
	if candidates.is_empty():
		return -1
	candidates.sort()
	var selected: int = candidates[stage_choice_index % candidates.size()]
	stage_choice_index += 1
	return selected


func _add_visible_source(counts: Dictionary, source_level: int) -> void:
	if source_level < 0 or source_level >= merge_game.max_level_index:
		return
	counts[source_level] = int(counts.get(source_level, 0)) + 1


func _complete_contract() -> void:
	debug_special_execution_count += 1
	var bonus_damage: int = _success_damage()
	result_text = "ORDER COMPLETE · BONUS %d" % bonus_damage
	battle.status_label.text = "ORDER COMPLETE"
	battle.status_label.modulate = Color("#70ff9b")
	log_event("ORDER COMPLETE", "mode=%d bonus=%d" % [enemy_mode, bonus_damage])
	if bonus_damage > 0:
		enemy.take_damage(bonus_damage)
	if not enemy.is_alive():
		_update_feedback()
		return
	pending_new_contract = true
	awaiting_next_route_step = true
	skip_next_turn_tick = true
	_update_feedback()


func _resolve_failure() -> void:
	debug_special_execution_count += 1
	var attack_damage: int = _failure_damage()
	result_text = "ORDER FAILED · DAMAGE %d" % attack_damage
	battle.status_label.text = "ORDER FAILED"
	battle.status_label.modulate = Color("#ff6b6b")
	log_event("ORDER FAILED", "mode=%d damage=%d" % [enemy_mode, attack_damage])
	if attack_damage > 0:
		enemy.attack_with_damage(player, attack_damage)
	if not player.is_alive() or not enemy.is_alive():
		_update_feedback()
		return
	_begin_contract()
	result_text = "ORDER FAILED · DAMAGE %d" % attack_damage
	_update_feedback()


func _turn_limit() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.turn_limits.size():
		return maxi(1, int(tuning.turn_limits[enemy_index]))
	return 4


func _success_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.success_bonus_damage.size():
		return maxi(0, int(tuning.success_bonus_damage[enemy_index]))
	return 20


func _failure_damage() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.failure_attack_damage.size():
		return maxi(0, int(tuning.failure_attack_damage[enemy_index]))
	return 15


func _route_length() -> int:
	if enemy_mode in [MODE_ZONE_ONLY, MODE_ZONE_AND_STAGE]:
		return 1
	return maxi(2, tuning.boss_route_length)


func _zone_for_x(x_position: float) -> int:
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var normalized: float = clampf((x_position - bounds.position.x) / bounds.size.x, 0.0, 0.9999)
	return clampi(floori(normalized * 3.0), 0, 2)


func _zone_name(zone: int) -> String:
	match clampi(zone, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	var stage_text: String = "ANY" if target_result_stage < 0 else "STAGE %d" % target_result_stage
	var current_step: int = mini(_route_length(), route_progress + 1)
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		target_zone,
		target_result_stage,
		current_step,
		_route_length(),
		turns_remaining,
		result_text,
		has_last_merge,
		last_merge_origin,
		last_merge_matched
	)
	var primary: String
	if _route_length() > 1:
		primary = "ROUTE %d/%d · %s · %s · %d TURN" % [current_step, _route_length(), _zone_name(target_zone), stage_text, turns_remaining]
	else:
		primary = "ORDER · %s · %s · %d TURN" % [_zone_name(target_zone), stage_text, turns_remaining]
	var detail: String = result_text if not result_text.is_empty() else "MAKE A NORMAL MERGE IN THE HIGHLIGHTED ZONE"
	battle.update_gimmick_ui(primary, detail)


func _on_cleanup() -> void:
	awaiting_next_route_step = false
	pending_new_contract = false
	skip_next_turn_tick = false
	result_text = ""
	has_last_merge = false
