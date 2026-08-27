class_name SuikaBallState
extends RefCounted

var ball: MergeBall
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var rotation := 0.0
var angular_velocity := 0.0
var radius := 1.0
var inverse_inertia := 0.0
var touched_this_step := false
var grounded_this_step := false
var sleep_elapsed := 0.0
var sleeping := false


func configure(source: MergeBall, shared_rotational_inertia: float) -> void:
	ball = source
	position = source.position
	velocity = source.linear_velocity
	rotation = source.rotation
	angular_velocity = source.angular_velocity
	radius = maxf(1.0, source.get_radius())
	inverse_inertia = 1.0 / maxf(1.0, shared_rotational_inertia)


func is_valid() -> bool:
	return is_instance_valid(ball) and not ball.is_queued_for_deletion()


func is_simulated() -> bool:
	return is_valid() and not ball.merge_locked


func is_static() -> bool:
	return not is_simulated() or ball.is_ice_frozen


func wake() -> void:
	sleeping = false
	sleep_elapsed = 0.0
