class_name SplitCascadeOverlay
extends Node2D

var target_position := Vector2.ZERO
var target_radius := 0.0
var cascade_active := false
var visible_target := false


func show_target(ball: MergeBall, cascade: bool) -> void:
	visible_target = is_instance_valid(ball)
	if visible_target:
		target_position = ball.position
		target_radius = ball.get_radius()
		cascade_active = cascade
	queue_redraw()


func clear_target() -> void:
	visible_target = false
	queue_redraw()


func _draw() -> void:
	if not visible_target:
		return
	if cascade_active:
		var ring_color := Color("#ff6b9d")
		draw_arc(target_position, target_radius + 17.0, 0.0, TAU, 40, ring_color, 4.0, true)
		draw_arc(target_position, target_radius + 25.0, -PI * 0.3, PI * 1.35, 32, Color("#ffd166"), 3.0, true)
		draw_string(
			ThemeDB.fallback_font,
			target_position + Vector2(-84.0, -target_radius - 36.0),
			"CASCADE SPLIT",
			HORIZONTAL_ALIGNMENT_CENTER,
			168.0,
			16,
			Color("#ffcfdf")
		)
