class_name TutorialControlArrow
extends Node2D

const LENGTH := 220.0
const MID_Y := 0.0


func _draw() -> void:
	var outline := Color(0.04, 0.07, 0.12, 0.95)
	draw_line(Vector2(0.0, MID_Y), Vector2(LENGTH, MID_Y), outline, 8.0, true)
	draw_line(Vector2(0.0, MID_Y), Vector2(LENGTH, MID_Y), Color.WHITE, 4.0, true)
	_draw_arrow_head(Vector2(0.0, MID_Y), -1.0, outline, 8.0)
	_draw_arrow_head(Vector2(0.0, MID_Y), -1.0, Color.WHITE, 4.0)
	_draw_arrow_head(Vector2(LENGTH, MID_Y), 1.0, outline, 8.0)
	_draw_arrow_head(Vector2(LENGTH, MID_Y), 1.0, Color.WHITE, 4.0)


func _draw_arrow_head(tip: Vector2, direction: float, color: Color, width: float) -> void:
	var back := -direction * 24.0
	draw_line(tip, tip + Vector2(back, -20.0), color, width, true)
	draw_line(tip, tip + Vector2(back, 20.0), color, width, true)
