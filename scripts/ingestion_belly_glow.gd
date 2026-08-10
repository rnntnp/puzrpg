class_name IngestionBellyGlow
extends Node2D

var glow_color := Color.WHITE


func show_glow(color: Color) -> void:
	glow_color = color
	visible = true
	queue_redraw()


func hide_glow() -> void:
	visible = false


func _draw() -> void:
	for layer in range(7, 0, -1):
		var weight := float(layer) / 7.0
		var radius := lerpf(9.0, 34.0, weight)
		var alpha := lerpf(0.34, 0.025, weight)
		draw_circle(Vector2.ZERO, radius, Color(glow_color, alpha))
	draw_circle(Vector2.ZERO, 7.0, Color(glow_color.lightened(0.35), 0.55))
