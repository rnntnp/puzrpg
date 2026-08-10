class_name MergeBurstEffect
extends Node2D

var _color := Color.WHITE
var _progress := 0.0
var _rays: Array[Vector2] = []
var _size_factor := 1.0
var _combo_count := 1
var _large_merge := false


func play(at: Vector2, color: Color, ball_radius: float, combo_count: int, ball_level: int) -> void:
	position = at
	_color = color
	_combo_count = maxi(1, combo_count)
	_large_merge = ball_level >= 6
	_size_factor = clampf(0.78 + ball_radius / 170.0, 0.9, 1.55)
	var ray_count := 12 + mini(12, (_combo_count - 1) * 3) + (6 if _large_merge else 0)
	for index in ray_count:
		var angle := TAU * float(index) / float(ray_count) + randf_range(-0.12, 0.12)
		_rays.append(Vector2.from_angle(angle) * randf_range(0.82, 1.18))
	var tween := create_tween()
	var duration := 0.34 + (0.08 if _large_merge else 0.0) + minf(0.1, float(_combo_count - 1) * 0.025)
	tween.tween_property(self, "_progress", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _progress
	var ring_color := _color.lerp(Color.WHITE, 0.55)
	ring_color.a = fade * 0.9
	var flash_strength := 0.13 + minf(0.14, float(_combo_count - 1) * 0.035) + (0.08 if _large_merge else 0.0)
	draw_circle(Vector2.ZERO, lerpf(8.0, 36.0, _progress) * _size_factor, Color(ring_color, fade * flash_strength))
	draw_arc(Vector2.ZERO, lerpf(5.0, 48.0, _progress) * _size_factor, 0.0, TAU, 48, ring_color, lerpf(11.0, 2.0, _progress), true)
	if _combo_count >= 2 or _large_merge:
		var second_ring := _color.lerp(Color.WHITE, 0.82)
		second_ring.a = fade * 0.78
		draw_arc(Vector2.ZERO, lerpf(12.0, 72.0, _progress) * _size_factor, 0.0, TAU, 56, second_ring, lerpf(7.0, 1.5, _progress), true)
	if _combo_count >= 3:
		var third_ring := _color
		third_ring.a = fade * 0.48
		draw_arc(Vector2.ZERO, lerpf(18.0, 94.0, _progress) * _size_factor, 0.0, TAU, 64, third_ring, 2.0, true)
	for index in _rays.size():
		var direction := _rays[index].normalized()
		var start := direction * lerpf(5.0, 25.0, _progress) * _size_factor
		var finish := direction * lerpf(18.0, 70.0 + float(index % 3) * 8.0, _progress) * _size_factor
		var ray_color := _color.lerp(Color.WHITE, 0.35 + 0.15 * float(index % 2))
		ray_color.a = fade
		draw_line(start, finish, ray_color, lerpf(5.0, 1.0, _progress), true)
		if index % 2 == 0:
			draw_circle(finish, lerpf(4.0, 1.0, _progress), ray_color)
		if (_combo_count >= 2 or _large_merge) and index % 3 == 0:
			var tangent := direction.orthogonal() * lerpf(7.0, 1.5, _progress)
			draw_colored_polygon(PackedVector2Array([
				finish + direction * 7.0,
				finish + tangent,
				finish - direction * 7.0,
				finish - tangent,
			]), ray_color)
