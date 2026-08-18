class_name TestGimmickHandler
extends Node

var battle: Battle
var enemy: Fighter
var player: Fighter
var merge_game: MergeGame
var data: TestGimmickData
var active := false
var busy := false
var debug_special_execution_count := 0
var active_tweens: Array[Tween] = []
var visual_layers: Array[Node2D] = []


func configure(
	battle_node: Battle,
	enemy_fighter: Fighter,
	player_fighter: Fighter,
	game: MergeGame,
	gimmick_data: TestGimmickData
) -> void:
	battle = battle_node
	enemy = enemy_fighter
	player = player_fighter
	merge_game = game
	data = gimmick_data
	active = data != null
	_connect_game_signals()
	_on_configured()


func on_turn_completed() -> void:
	pass


func transition_enemy(enemy_fighter: Fighter) -> void:
	enemy = enemy_fighter
	active = data != null
	busy = false
	_on_enemy_changed()


func modify_player_damage(
	damage: int,
	_merge_result_level_index := -1,
	_combo_count := 1,
	_merge_origin := Vector2.ZERO
) -> int:
	return damage


func cleanup() -> void:
	active = false
	busy = false
	_disconnect_game_signals()
	for tween in active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	active_tweens.clear()
	_on_cleanup()
	for layer in visual_layers:
		if not is_instance_valid(layer):
			continue
		if layer.get_parent() != null:
			layer.get_parent().remove_child(layer)
		layer.queue_free()
	visual_layers.clear()
	if is_instance_valid(merge_game):
		merge_game.reset_gimmick_state()
	if is_instance_valid(battle):
		battle.update_gimmick_ui("", "")


func _on_configured() -> void:
	pass


func _on_cleanup() -> void:
	pass


func _on_enemy_changed() -> void:
	pass


func _physics_process_gimmick(_delta: float) -> void:
	pass


func _on_merge_completed(_merged_ball: MergeBall) -> void:
	pass


func _on_merge_registered(
	_result_level: int,
	_origin: Vector2,
	_chain_index: int,
	_source_ids: Array[int],
	_involved_cursed: bool
) -> void:
	pass


func _on_player_ball_landed(_level: int, _drop_x: float) -> void:
	pass


func _on_player_ball_dropped() -> void:
	pass


func _physics_process(delta: float) -> void:
	if active and is_instance_valid(merge_game):
		_physics_process_gimmick(delta)


func _connect_game_signals() -> void:
	if not is_instance_valid(merge_game):
		return
	if not merge_game.merge_completed.is_connected(_on_merge_completed):
		merge_game.merge_completed.connect(_on_merge_completed)
	if not merge_game.merge_registered.is_connected(_on_merge_registered):
		merge_game.merge_registered.connect(_on_merge_registered)
	if not merge_game.player_ball_landed.is_connected(_on_player_ball_landed):
		merge_game.player_ball_landed.connect(_on_player_ball_landed)
	if not merge_game.ball_dropped.is_connected(_on_player_ball_dropped):
		merge_game.ball_dropped.connect(_on_player_ball_dropped)


func _disconnect_game_signals() -> void:
	if not is_instance_valid(merge_game):
		return
	if merge_game.merge_completed.is_connected(_on_merge_completed):
		merge_game.merge_completed.disconnect(_on_merge_completed)
	if merge_game.merge_registered.is_connected(_on_merge_registered):
		merge_game.merge_registered.disconnect(_on_merge_registered)
	if merge_game.player_ball_landed.is_connected(_on_player_ball_landed):
		merge_game.player_ball_landed.disconnect(_on_player_ball_landed)
	if merge_game.ball_dropped.is_connected(_on_player_ball_dropped):
		merge_game.ball_dropped.disconnect(_on_player_ball_dropped)


func valid_balls(minimum_stage := 1, maximum_stage := 11) -> Array[MergeBall]:
	var result: Array[MergeBall] = []
	if not is_instance_valid(merge_game):
		return result
	for child in merge_game.get_active_balls():
		if not child is MergeBall:
			continue
		var ball: MergeBall = child as MergeBall
		var stage: int = ball.merge_level + 1
		if ball.merge_locked or ball.is_queued_for_deletion() or stage < minimum_stage or stage > maximum_stage:
			continue
		result.append(ball)
	return result


func topmost_ball(minimum_stage := 1, maximum_stage := 11) -> MergeBall:
	var candidates: Array[MergeBall] = valid_balls(minimum_stage, maximum_stage)
	candidates.sort_custom(func(a: MergeBall, b: MergeBall) -> bool: return a.position.y < b.position.y)
	return candidates.front() if not candidates.is_empty() else null


func create_gimmick_tween() -> Tween:
	var tween: Tween = create_tween()
	active_tweens.append(tween)
	return tween


func attach_visual_layer(layer: Node2D) -> Node2D:
	if layer == null or not is_instance_valid(merge_game):
		return null
	merge_game.gimmick_overlay.add_child(layer)
	visual_layers.append(layer)
	return layer


func log_event(event: String, detail: String) -> void:
	if data != null and data.debug_logging:
		print("[GIMMICK %s] %s | %s" % [data.display_name, event, detail])
