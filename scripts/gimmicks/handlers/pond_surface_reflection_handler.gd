extends "res://scripts/gimmicks/handlers/directional_gravity_handler.gd"

const ReflectionConfig = preload("res://scripts/gimmicks/configs/pond_surface_reflection_config.gd")
const ReflectionLayer = preload("res://scripts/gimmicks/visuals/pond_surface_reflection_layer.gd")
var reflections: Node2D


func _on_configured() -> void:
	if data.tuning == null:
		data = data.duplicate()
		data.tuning = ReflectionConfig.new()
	super._on_configured()
	reflections = attach_visual_layer(ReflectionLayer.new())
	reflections.configure(merge_game, tuning.rendering_settings)


func _on_cleanup() -> void:
	if is_instance_valid(reflections):
		reflections.restore_visuals()
	super._on_cleanup()
