class_name TestGimmickController
extends Node

const LegacyHandler = preload("res://scripts/gimmicks/handlers/legacy_test_gimmick_handler.gd")

var data: TestGimmickData
var active_handler: Node

var busy: bool:
	get:
		return bool(active_handler.get("busy")) if is_instance_valid(active_handler) else false

var debug_special_execution_count: int:
	get:
		return int(active_handler.get("debug_special_execution_count")) if is_instance_valid(active_handler) else 0


func configure(
	battle_node: Battle,
	enemy_fighter: Fighter,
	player_fighter: Fighter,
	game: MergeGame,
	gimmick_data: TestGimmickData
) -> void:
	if (
		is_instance_valid(active_handler)
		and active_handler is TestGimmickHandler
		and data == gimmick_data
		and gimmick_data != null
		and gimmick_data.preserve_board_between_enemies
	):
		active_handler.call("transition_enemy", enemy_fighter)
		return
	cleanup()
	data = gimmick_data
	if data == null:
		return
	var handler_script: Script = data.handler_script
	active_handler = (handler_script.new() if handler_script != null else LegacyHandler.new()) as Node
	if active_handler == null:
		push_error("Test gimmick handler must extend Node: %s" % data.display_name)
		return
	if handler_script != null and not active_handler is TestGimmickHandler:
		push_error("Modular test gimmick handlers must extend TestGimmickHandler: %s" % data.display_name)
		active_handler.queue_free()
		active_handler = null
		return
	active_handler.name = "ActiveGimmickHandler"
	add_child(active_handler)
	active_handler.call("configure", battle_node, enemy_fighter, player_fighter, game, data)


func on_turn_completed() -> void:
	if is_instance_valid(active_handler):
		active_handler.call("on_turn_completed")


func modify_player_damage(
	damage: int,
	merge_result_level_index := -1,
	combo_count := 1,
	merge_origin := Vector2.ZERO
) -> int:
	if not is_instance_valid(active_handler):
		return damage
	return int(active_handler.call(
		"modify_player_damage",
		damage,
		merge_result_level_index,
		combo_count,
		merge_origin
	))


func should_preserve_between_enemies() -> bool:
	return data != null and data.preserve_board_between_enemies


func cleanup() -> void:
	if is_instance_valid(active_handler):
		active_handler.call("cleanup")
		active_handler.queue_free()
	active_handler = null
	data = null
