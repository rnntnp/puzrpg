class_name IceCastEffect
extends Node2D

signal arrived

@onready var trail: Line2D = $Trail
@onready var glow: Sprite2D = $Projectile/Glow
@onready var projectile: Sprite2D = $Projectile
@onready var impact_ring: Sprite2D = $ImpactRing

var _start_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _control_position := Vector2.ZERO


func play(from_global: Vector2, to_global: Vector2) -> void:
	global_position = Vector2.ZERO
	_start_position = from_global
	_target_position = to_global
	_control_position = (_start_position + _target_position) * 0.5 + Vector2(0.0, -75.0)
	projectile.global_position = _start_position
	projectile.scale = Vector2(0.18, 0.18)
	impact_ring.visible = false
	trail.clear_points()
	var flight := create_tween().set_parallel()
	flight.tween_method(_update_flight, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(projectile, "rotation", TAU * 1.5, 0.42)
	flight.tween_property(projectile, "scale", Vector2(0.28, 0.28), 0.42).set_trans(Tween.TRANS_BACK)
	await flight.finished
	projectile.visible = false
	impact_ring.visible = true
	impact_ring.global_position = _target_position
	impact_ring.scale = Vector2(0.15, 0.15)
	impact_ring.modulate = Color(0.72, 0.96, 1.0, 1.0)
	arrived.emit()
	var impact := create_tween().set_parallel()
	impact.tween_property(impact_ring, "scale", Vector2(0.62, 0.62), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact.tween_property(impact_ring, "modulate:a", 0.0, 0.22).set_delay(0.05)
	impact.tween_property(trail, "modulate:a", 0.0, 0.18)
	await impact.finished
	queue_free()


func _update_flight(weight: float) -> void:
	var first_leg := _start_position.lerp(_control_position, weight)
	var second_leg := _control_position.lerp(_target_position, weight)
	projectile.global_position = first_leg.lerp(second_leg, weight)
	trail.add_point(projectile.global_position)
	while trail.get_point_count() > 14:
		trail.remove_point(0)
	glow.modulate.a = 0.35 + sin(weight * PI) * 0.45
