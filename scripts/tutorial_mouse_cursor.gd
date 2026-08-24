class_name TutorialMouseCursor
extends Node2D


func _draw() -> void:
	var pointer := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, 76.0), Vector2(20.0, 58.0),
		Vector2(33.0, 91.0), Vector2(48.0, 84.0), Vector2(34.0, 51.0),
		Vector2(62.0, 48.0), Vector2(0.0, 0.0),
	])
	draw_colored_polygon(pointer, Color.WHITE)
	draw_polyline(pointer, Color(0.04, 0.07, 0.12, 1.0), 5.0, true)
