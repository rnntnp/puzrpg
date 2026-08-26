class_name IceEyeGlow
extends Node2D

const GLOW_COLOR := Color("#35bfff")
const CORE_COLOR := Color("#d9f8ff")

var eye_positions: Array[Vector2] = []
var _phase := 0.0


func _ready() -> void:
	z_index = 20
	visible = false
	set_process(false)


func show_glow(positions: Array[Vector2]) -> void:
	eye_positions = positions.duplicate()
	_phase = 0.0
	visible = not eye_positions.is_empty()
	set_process(visible)
	queue_redraw()


func hide_glow() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 5.0, TAU)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.82 + sin(_phase) * 0.18
	for eye_position: Vector2 in eye_positions:
		draw_circle(eye_position, 17.0 * pulse, Color(GLOW_COLOR, 0.13))
		draw_circle(eye_position, 9.5 * pulse, Color(GLOW_COLOR, 0.35))
		draw_line(
			eye_position + Vector2(-13.0 * pulse, 0.0),
			eye_position + Vector2(13.0 * pulse, 0.0),
			Color(GLOW_COLOR, 0.48),
			3.0,
			true
		)
		draw_circle(eye_position, 4.5, GLOW_COLOR)
		draw_circle(eye_position, 2.0, CORE_COLOR)
