extends "res://scripts/gimmicks/handlers/contact_stop_merge_loadout_handler.gd"

const DirectionalConfig = preload("res://scripts/gimmicks/configs/directional_gravity_config.gd")
const DirectionalLauncher = preload("res://scripts/gimmicks/visuals/directional_gravity_launcher.gd")


func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else DirectionalConfig.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(DirectionalLauncher.new())
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	last_effect = ""
	_on_enemy_changed()
