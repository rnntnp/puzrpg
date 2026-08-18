class_name MergeLinkNetworkHandler
extends TestGimmickHandler

const MergeLinkNetworkConfigClass = preload("res://scripts/gimmicks/configs/merge_link_network_config.gd")
const MergeLinkNetworkOverlayClass = preload("res://scripts/gimmicks/visuals/merge_link_network_overlay.gd")
const MODE_TEACH := 0
const MODE_BRIDGE := 1
const MODE_BRANCH := 2
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var tuning: MergeLinkNetworkConfigClass
var overlay: MergeLinkNetworkOverlayClass
var enemy_mode := MODE_TEACH
var contract_index := 0
var turns_remaining := 0
var markers: Array[Dictionary] = []
var anchor_positions: Array[Vector2] = []
var anchor_labels: Array[String] = []
var anchor_connected: Array[bool] = []
var result_text := ""
var result_state := RESULT_NEUTRAL


func _on_configured() -> void:
	tuning = data.tuning as MergeLinkNetworkConfigClass
	if tuning == null:
		tuning = MergeLinkNetworkConfigClass.new()
	overlay = attach_visual_layer(MergeLinkNetworkOverlayClass.new()) as MergeLinkNetworkOverlayClass
	_configure_enemy()


func _on_enemy_changed() -> void:
	_configure_enemy()


func _configure_enemy() -> void:
	var enemy_index: int = battle.current_enemy_index
	enemy_mode = clampi(int(tuning.enemy_modes[enemy_index]), MODE_TEACH, MODE_BRANCH) if enemy_index >= 0 and enemy_index < tuning.enemy_modes.size() else MODE_BRANCH
	contract_index = 0
	result_text = ""
	result_state = RESULT_NEUTRAL
	_begin_contract()


func _on_player_ball_dropped() -> void:
	if not active or busy:
		return
	result_text = ""
	result_state = RESULT_NEUTRAL
	if is_instance_valid(battle):
		battle.status_label.text = "전투 중"
		battle.status_label.modulate = Color.WHITE
	_update_feedback()


func _on_merge_registered(
	_result_level: int,
	origin: Vector2,
	_chain_index: int,
	_source_ids: Array[int],
	_involved_cursed: bool
) -> void:
	if not active or busy or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	markers.append({
		"position": origin,
		"turns": _node_lifetime(),
	})
	while markers.size() > maxi(1, tuning.maximum_nodes):
		markers.pop_front()
	_refresh_network_state()
	log_event("LINK NODE", "position=%s nodes=%d" % [str(origin), markers.size()])
	_update_feedback()


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	_refresh_network_state()
	if _network_complete():
		_resolve_contract(true)
		return
	_age_markers()
	turns_remaining = maxi(0, turns_remaining - 1)
	_refresh_network_state()
	if turns_remaining <= 0:
		_resolve_contract(false)
		return
	_update_feedback()


func _resolve_contract(succeeded: bool) -> void:
	busy = true
	merge_game.set_input_enabled(false)
	debug_special_execution_count += 1
	if succeeded:
		var bonus_damage: int = _success_damage()
		result_text = "NETWORK COMPLETE · BONUS %d" % bonus_damage
		result_state = RESULT_SUCCESS
		battle.status_label.text = "연결망 완성"
		battle.status_label.modulate = Color("#70ff9b")
		log_event("NETWORK COMPLETE", "mode=%d nodes=%d" % [enemy_mode, markers.size()])
		if bonus_damage > 0:
			enemy.take_damage(bonus_damage)
	else:
		var attack_damage: int = _failure_damage()
		result_text = "NETWORK FAILED · DAMAGE %d" % attack_damage
		result_state = RESULT_FAILURE
		battle.status_label.text = "연결망 실패"
		battle.status_label.modulate = Color("#ff6b6b")
		log_event("NETWORK FAILED", "mode=%d nodes=%d" % [enemy_mode, markers.size()])
		if attack_damage > 0:
			enemy.attack_with_damage(player, attack_damage)
	_update_feedback()
	if not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	await get_tree().create_timer(tuning.result_feedback_duration, true, false, true).timeout
	if not active or not is_instance_valid(enemy) or not enemy.is_alive() or not player.is_alive():
		busy = false
		return
	contract_index += 1
	result_text = ""
	result_state = RESULT_NEUTRAL
	battle.status_label.text = "전투 중"
	battle.status_label.modulate = Color.WHITE
	_begin_contract()
	merge_game.set_input_enabled(true)
	busy = false


func _begin_contract() -> void:
	markers.clear()
	_build_anchors()
	turns_remaining = _contract_turn_limit()
	_refresh_network_state()
	_update_feedback()


func _build_anchors() -> void:
	anchor_positions.clear()
	anchor_labels.clear()
	var bounds: Rect2 = merge_game.get_base_board_bounds()
	var left_x: float = bounds.position.x + bounds.size.x * tuning.side_anchor_inset_ratio
	var center_x: float = bounds.get_center().x
	var right_x: float = bounds.end.x - bounds.size.x * tuning.side_anchor_inset_ratio
	match enemy_mode:
		MODE_TEACH:
			var anchor_kind: int = _teach_anchor_at(contract_index)
			var anchor_x: float = center_x
			if anchor_kind == 0:
				anchor_x = left_x
			elif anchor_kind == 2:
				anchor_x = right_x
			anchor_positions.append(Vector2(anchor_x, bounds.position.y + bounds.size.y * tuning.teach_anchor_y_ratio))
			anchor_labels.append(_anchor_name(anchor_kind))
		MODE_BRIDGE:
			var bridge_y: float = bounds.position.y + bounds.size.y * tuning.twist_anchor_y_ratio
			anchor_positions.append(Vector2(left_x, bridge_y))
			anchor_positions.append(Vector2(right_x, bridge_y))
			anchor_labels.assign(["LEFT", "RIGHT"])
		MODE_BRANCH:
			var side_y: float = bounds.position.y + bounds.size.y * tuning.boss_side_anchor_y_ratio
			var center_y: float = bounds.position.y + bounds.size.y * tuning.boss_center_anchor_y_ratio
			anchor_positions.append(Vector2(left_x, side_y))
			anchor_positions.append(Vector2(center_x, center_y))
			anchor_positions.append(Vector2(right_x, side_y))
			anchor_labels.assign(["LEFT", "CENTER", "RIGHT"])


func _refresh_network_state() -> void:
	anchor_connected.assign(_read_anchor_connections())


func _read_anchor_connections() -> Array[bool]:
	var connected: Array[bool] = []
	connected.resize(anchor_positions.size())
	connected.fill(false)
	if anchor_positions.is_empty() or markers.is_empty():
		return connected
	if anchor_positions.size() == 1:
		for marker: Dictionary in markers:
			var marker_position: Vector2 = marker.get("position", Vector2.ZERO)
			if anchor_positions[0].distance_to(marker_position) <= tuning.anchor_reach_distance:
				connected[0] = true
				break
		return connected

	var positions: Array[Vector2] = []
	positions.append_array(anchor_positions)
	for marker: Dictionary in markers:
		var marker_position: Vector2 = marker.get("position", Vector2.ZERO)
		positions.append(marker_position)
	var visited: Array[bool] = []
	visited.resize(positions.size())
	visited.fill(false)
	var queue: Array[int] = [0]
	var queue_cursor := 0
	visited[0] = true
	while queue_cursor < queue.size():
		var current_index: int = queue[queue_cursor]
		queue_cursor += 1
		for candidate_index in positions.size():
			if visited[candidate_index] or not _can_link(current_index, candidate_index, positions):
				continue
			visited[candidate_index] = true
			queue.append(candidate_index)
	var component_has_marker := false
	for index in range(anchor_positions.size(), positions.size()):
		if visited[index]:
			component_has_marker = true
			break
	if not component_has_marker:
		return connected
	for anchor_index in anchor_positions.size():
		connected[anchor_index] = visited[anchor_index]
	return connected


func _can_link(first_index: int, second_index: int, positions: Array[Vector2]) -> bool:
	if first_index == second_index:
		return false
	var anchor_count: int = anchor_positions.size()
	var first_is_anchor: bool = first_index < anchor_count
	var second_is_anchor: bool = second_index < anchor_count
	if first_is_anchor and second_is_anchor:
		return false
	var maximum_distance: float = tuning.anchor_reach_distance if first_is_anchor or second_is_anchor else tuning.node_link_distance
	return positions[first_index].distance_to(positions[second_index]) <= maximum_distance


func _network_complete() -> bool:
	if anchor_connected.is_empty():
		return false
	for is_connected: bool in anchor_connected:
		if not is_connected:
			return false
	return true


func _age_markers() -> void:
	for index in range(markers.size() - 1, -1, -1):
		var marker: Dictionary = markers[index]
		var remaining: int = int(marker.get("turns", 0)) - 1
		if remaining <= 0:
			markers.remove_at(index)
			continue
		marker["turns"] = remaining
		markers[index] = marker


func _teach_anchor_at(index: int) -> int:
	if tuning.teach_anchor_pattern.is_empty():
		return index % 3
	return clampi(int(tuning.teach_anchor_pattern[index % tuning.teach_anchor_pattern.size()]), 0, 2)


func _contract_turn_limit() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.contract_turn_limits.size():
		return maxi(1, int(tuning.contract_turn_limits[enemy_index]))
	return 5


func _node_lifetime() -> int:
	var enemy_index: int = battle.current_enemy_index
	if enemy_index >= 0 and enemy_index < tuning.node_lifetimes.size():
		return maxi(1, int(tuning.node_lifetimes[enemy_index]))
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
	return 12


func _anchor_name(anchor_kind: int) -> String:
	match clampi(anchor_kind, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"


func _mode_name() -> String:
	match enemy_mode:
		MODE_TEACH: return "BEACON"
		MODE_BRIDGE: return "BRIDGE"
		_: return "BRANCH"


func _update_feedback() -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(merge_game) or not is_instance_valid(battle):
		return
	overlay.show_state(
		merge_game.get_base_board_bounds(),
		anchor_positions,
		anchor_labels,
		anchor_connected,
		markers,
		tuning.node_link_distance,
		tuning.anchor_reach_distance,
		turns_remaining,
		result_text,
		result_state
	)
	var connected_count := 0
	for is_connected: bool in anchor_connected:
		if is_connected:
			connected_count += 1
	battle.update_gimmick_ui(
		"LINK %s · %d턴" % [_mode_name(), turns_remaining],
		"비콘 %d/%d · 노드 %d · 수명 %d턴" % [connected_count, anchor_positions.size(), markers.size(), _node_lifetime()]
	)


func _on_cleanup() -> void:
	markers.clear()
	anchor_positions.clear()
	anchor_labels.clear()
	anchor_connected.clear()
	result_text = ""
	result_state = RESULT_NEUTRAL
