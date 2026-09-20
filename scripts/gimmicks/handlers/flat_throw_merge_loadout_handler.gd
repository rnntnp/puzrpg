extends "res://scripts/gimmicks/handlers/merge_loadout_handler.gd"

const FlatThrowConfig = preload("res://scripts/gimmicks/configs/flat_throw_config.gd")
const FlatThrowLauncher = preload("res://scripts/gimmicks/visuals/flat_throw_launcher.gd")


func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else FlatThrowConfig.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(FlatThrowLauncher.new())
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	merge_game.player_merge_velocity_modifier = _reduce_merge_velocity
	last_effect = "드래그 방향과 길이로 던지고, 바닥 마찰로 빠르게 정지"
	_on_enemy_changed()


func _reduce_merge_velocity(velocity: Vector2) -> Vector2:
	return velocity * tuning.merge_velocity_retention
