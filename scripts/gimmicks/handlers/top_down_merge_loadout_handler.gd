extends "res://scripts/gimmicks/handlers/merge_loadout_handler.gd"

const TopDownLauncher = preload("res://scripts/gimmicks/visuals/top_down_aim_launcher.gd")


func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else Config.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(TopDownLauncher.new())
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	last_effect = "위쪽 발사구에서 방향을 정한 뒤 놓으면 고정된 힘으로 발사"
	_on_enemy_changed()
