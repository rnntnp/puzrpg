extends "res://scripts/gimmicks/handlers/merge_loadout_handler.gd"

const ReverseDropConfig = preload("res://scripts/gimmicks/configs/contact_stop_config.gd")
const ReverseDropBoard = preload("res://scripts/gimmicks/visuals/contact_stop_launcher.gd")


func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else ReverseDropConfig.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(ReverseDropBoard.new())
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	last_effect = ""
	_on_enemy_changed()


func _on_player_ball_dropped() -> void:
	if is_instance_valid(launcher):
		launcher.configure_active_balls()


func _on_merge_completed(_ball: MergeBall) -> void:
	if is_instance_valid(launcher):
		launcher.configure_active_balls()
