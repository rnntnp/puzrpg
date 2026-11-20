extends "res://scripts/gimmicks/handlers/pond_surface_reflection_handler.gd"

const CircleLayer = preload("res://scripts/gimmicks/visuals/circle_xpbd_pond_layer.gd")
const PlayerVisual = preload("res://scripts/gimmicks/visuals/compound_pond_player.gd")

var soft_balls: Node2D
var player_visual: Node2D


func _on_configured() -> void:
	super._on_configured()
	player_visual = attach_visual_layer(PlayerVisual.new())
	player_visual.reparent(player, false)
	player_visual.configure(player, 1.17, true)
	soft_balls = attach_visual_layer(CircleLayer.new())
	soft_balls.configure(merge_game, tuning)


func _integrate_reflection_with_outline() -> bool:
	return true


func _on_cleanup() -> void:
	if is_instance_valid(player_visual):
		player_visual.restore()
	if is_instance_valid(soft_balls):
		soft_balls.restore_balls()
	super._on_cleanup()
