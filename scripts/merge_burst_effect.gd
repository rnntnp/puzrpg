class_name MergeBurstEffect
extends Node2D

var _color := Color.WHITE
var _progress := 0.0
var _rays: Array[Vector2] = []


func play(at: Vector2, color: Color) -> void:
	position = at
	_color = color
	for index in 12:
		var angle := TAU * float(index) / 12.0 + randf_range(-0.12, 0.12)
		_rays.append(Vector2.from_angle(angle) * randf_range(0.82, 1.18))
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _progress
	var ring_color := _color.lerp(Color.WHITE, 0.55)
	ring_color.a = fade * 0.9
	draw_circle(Vector2.ZERO, lerpf(8.0, 32.0, _progress), Color(ring_color, fade * 0.13))
	draw_arc(Vector2.ZERO, lerpf(5.0, 45.0, _progress), 0.0, TAU, 40, ring_color, lerpf(10.0, 2.0, _progress), true)
	for index in _rays.size():
		var direction := _rays[index].normalized()
		var start := direction * lerpf(5.0, 25.0, _progress)
		var finish := direction * lerpf(18.0, 70.0 + float(index % 3) * 8.0, _progress)
		var ray_color := _color.lerp(Color.WHITE, 0.35 + 0.15 * float(index % 2))
		ray_color.a = fade
		draw_line(start, finish, ray_color, lerpf(5.0, 1.0, _progress), true)
		if index % 2 == 0:
			draw_circle(finish, lerpf(4.0, 1.0, _progress), ray_color)
