class_name TutorialPointerArrow
extends Node2D

const SHAFT_END := Vector2(56.0, 120.0)
const OUTLINE_COLOR := Color(0.02, 0.03, 0.07, 0.98)
const FILL_COLOR := Color("#ffd166")


func _draw() -> void:
	var direction := SHAFT_END.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	_draw_arrow(Vector2.ZERO, direction, perpendicular, OUTLINE_COLOR, 28.0, 48.0)
	_draw_arrow(Vector2.ZERO, direction, perpendicular, FILL_COLOR, 17.0, 39.0)


func _draw_arrow(tip: Vector2, direction: Vector2, perpendicular: Vector2, color: Color, width: float, head_length: float) -> void:
	draw_line(SHAFT_END, tip + direction * 20.0, color, width, true)
	var head_base := tip + direction * head_length
	var head_half_width := head_length * 0.58
	draw_colored_polygon(PackedVector2Array([
		tip,
		head_base + perpendicular * head_half_width,
		head_base - perpendicular * head_half_width,
	]), color)
