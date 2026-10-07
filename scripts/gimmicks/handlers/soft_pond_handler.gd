extends "res://scripts/gimmicks/handlers/pond_surface_reflection_handler.gd"

const SoftLayer = preload("res://scripts/gimmicks/visuals/soft_pond_layer.gd")
var soft_balls: Node2D

func _on_configured() -> void:
	super._on_configured()
	soft_balls = attach_visual_layer(SoftLayer.new())
	soft_balls.configure(merge_game, tuning)
	launcher.flight_velocity_integrator = soft_balls.integrate_flight_velocity
	launcher.prediction_step_seconds = 1.0 / (60.0 * tuning.solver_substeps)

func _on_cleanup() -> void:
	if is_instance_valid(soft_balls):
		soft_balls.restore_balls()
	super._on_cleanup()
