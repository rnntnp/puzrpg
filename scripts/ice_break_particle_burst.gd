class_name IceBreakParticleBurst
extends Node2D

const PARTICLE_COUNT := 16
const BURST_DURATION := 0.5

var _particles: Array[Dictionary] = []
var _elapsed := 0.0


func play(at_global_position: Vector2) -> void:
	global_position = at_global_position
	z_index = 20
	for index in PARTICLE_COUNT:
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(38.0, 92.0)
		_particles.append({
			"position": Vector2.ZERO,
			"velocity": Vector2.from_angle(angle) * speed,
			"radius": randf_range(2.0, 4.2),
			"delay": randf_range(0.0, 0.08),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for particle in _particles:
		if _elapsed < float(particle["delay"]):
			continue
		var particle_position: Vector2 = particle["position"]
		var particle_velocity: Vector2 = particle["velocity"]
		particle["position"] = particle_position + particle_velocity * delta
		particle["velocity"] = particle_velocity * 0.94
	queue_redraw()
	if _elapsed >= BURST_DURATION:
		queue_free()


func _draw() -> void:
	for particle in _particles:
		var particle_age := maxf(0.0, _elapsed - float(particle["delay"]))
		if particle_age <= 0.0:
			continue
		var progress := clampf(particle_age / BURST_DURATION, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(0.35, 1.0, progress)
		var radius := float(particle["radius"]) * lerpf(1.0, 0.45, progress)
		var particle_position: Vector2 = particle["position"]
		draw_circle(particle_position, radius, Color(1.0, 1.0, 1.0, alpha))
