class_name PlayerSkillBreakEffect
extends Node2D

const YELLOW := Color("#ffd84f")
const BRIGHT_YELLOW := Color("#fff3a3")
const DARK_GOLD := Color("#8a5a00")
const DURATION := 0.62

var _elapsed := 0.0
var _shards: Array[Dictionary] = []


func play(at_global: Vector2) -> void:
	global_position = at_global
	var random := RandomNumberGenerator.new()
	random.seed = Time.get_ticks_usec()
	for index in 22:
		var angle := TAU * float(index) / 22.0 + random.randf_range(-0.14, 0.14)
		var speed := random.randf_range(150.0, 290.0)
		_shards.append({
			"position": Vector2.from_angle(angle) * random.randf_range(4.0, 18.0),
			"velocity": Vector2.from_angle(angle) * speed + Vector2(0.0, random.randf_range(-55.0, 20.0)),
			"rotation": random.randf_range(0.0, TAU),
			"spin": random.randf_range(-10.0, 10.0),
			"size": random.randf_range(5.0, 11.0),
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for shard in _shards:
		var velocity: Vector2 = shard["velocity"]
		velocity += Vector2(0.0, 310.0) * delta
		shard["velocity"] = velocity
		var shard_position: Vector2 = shard["position"]
		shard["position"] = shard_position + velocity * delta
		shard["rotation"] = float(shard["rotation"]) + float(shard["spin"]) * delta
	queue_redraw()
	if _elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var impact_fade := 1.0 - clampf(progress * 2.2, 0.0, 1.0)
	var ring_color := YELLOW
	ring_color.a = impact_fade * 0.95
	draw_circle(Vector2.ZERO, lerpf(9.0, 42.0, progress), Color(YELLOW, impact_fade * 0.22))
	draw_arc(Vector2.ZERO, lerpf(12.0, 58.0, progress), 0.0, TAU, 48, ring_color, lerpf(9.0, 2.0, progress), true)
	for index in 10:
		var direction := Vector2.from_angle(TAU * float(index) / 10.0 + 0.18)
		draw_line(
			direction * lerpf(5.0, 24.0, progress),
			direction * lerpf(28.0, 76.0, progress),
			Color(BRIGHT_YELLOW, impact_fade),
			lerpf(6.0, 1.0, progress),
			true
		)
	var shard_fade := 1.0 - smoothstep(0.62, 1.0, progress)
	for index in _shards.size():
		var shard := _shards[index]
		var shard_position: Vector2 = shard["position"]
		var shard_rotation: float = shard["rotation"]
		var shard_size: float = shard["size"]
		var forward := Vector2.from_angle(shard_rotation)
		var side := forward.orthogonal()
		var points := PackedVector2Array([
			shard_position + forward * shard_size,
			shard_position - forward * shard_size * 0.72 + side * shard_size * 0.58,
			shard_position - forward * shard_size * 0.48 - side * shard_size * 0.48,
		])
		var fill := BRIGHT_YELLOW if index % 3 == 0 else YELLOW
		fill.a = shard_fade
		draw_colored_polygon(points, fill)
		var outline := DARK_GOLD
		outline.a = shard_fade * 0.88
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), outline, 1.5, true)
