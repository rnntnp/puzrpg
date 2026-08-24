class_name BallGlow
extends Node2D

var glow_radius := 0.0
var glow_color := Color.WHITE
var glow_strength := 0.0


func setup(radius: float, color: Color, strength: float) -> void:
	glow_radius = radius
	glow_color = color
	glow_strength = strength
	queue_redraw()


func _draw() -> void:
	if glow_radius <= 0.0 or glow_strength <= 0.0:
		return
	for index in 12:
		var ratio := float(index) / 11.0
		var radius := lerpf(glow_radius * 1.7, glow_radius * 1.01, ratio)
		var eased_ratio := pow(ratio, 1.5)
		var alpha := glow_strength * lerpf(0.006, 0.03, eased_ratio)
		draw_circle(Vector2.ZERO, radius, Color(glow_color, alpha))
