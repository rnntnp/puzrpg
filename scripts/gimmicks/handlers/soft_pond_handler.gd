extends "res://scripts/gimmicks/handlers/pond_surface_reflection_handler.gd"

const SoftLayer = preload("res://scripts/gimmicks/visuals/soft_pond_layer.gd")
var soft_balls: Node2D

func _on_configured() -> void:
	super._on_configured()
	soft_balls = attach_visual_layer(SoftLayer.new())
	soft_balls.configure(merge_game, tuning)

func _on_cleanup() -> void:
	if is_instance_valid(soft_balls):
		soft_balls.restore_balls()
	super._on_cleanup()
