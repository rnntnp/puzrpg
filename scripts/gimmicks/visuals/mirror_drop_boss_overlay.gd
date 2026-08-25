class_name MirrorDropBossOverlay
extends Node2D

const PHASE_NORMAL := 0
const PHASE_MIRROR := 1

var bounds := Rect2()
var phase := PHASE_NORMAL
var mirror_x := 0.0
var drop_y := 0.0
var mirror_action_active := false


func show_state(
	board_bounds: Rect2,
	phase_value: int,
	ghost_x: float,
	spawn_y: float,
	action_active: bool
) -> void:
	bounds = board_bounds
	phase = phase_value
	mirror_x = ghost_x
	drop_y = spawn_y
	mirror_action_active = action_active
	queue_redraw()


func _draw() -> void:
	if phase != PHASE_MIRROR:
		return
	var center_x: float = bounds.get_center().x
	draw_dashed_line(
		Vector2(center_x, bounds.position.y),
		Vector2(center_x, bounds.end.y),
		Color(0.75, 0.9, 1.0, 0.30),
		2.0,
		9.0
	)
	_draw_mirror_marker()


func _draw_mirror_marker() -> void:
	var alpha := 0.72 if not mirror_action_active else 1.0
	var center := Vector2(mirror_x, drop_y)
	draw_circle(center, 18.0, Color(0.68, 0.88, 1.0, 0.22 * alpha))
	draw_arc(center, 18.0, 0.0, TAU, 28, Color(0.8, 0.94, 1.0, 0.85 * alpha), 3.0, true)
