class_name DangerLine
extends Node2D

enum State { SAFE, WARNING, DANGER }

@export var start_x := 102.0
@export var end_x := 618.0
@export var line_y := 230.0
@export var dash_length := 16.0
@export var gap_length := 11.0
@export var line_width := 4.0
@export var line_color := Color(1.0, 0.25, 0.32, 0.72)

var state := State.SAFE
var pulse_time := 0.0


func _ready() -> void:
	queue_redraw()


func configure(left: float, right: float, y_position: float) -> void:
	start_x = left
	end_x = right
	line_y = y_position
	queue_redraw()

func set_state(next_state: int) -> void:
	state = next_state
	queue_redraw()

func _process(delta: float) -> void:
	if state == State.SAFE:
		return
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := (sin(pulse_time * (3.0 if state == State.WARNING else 9.0)) + 1.0) * 0.5
	var color := line_color
	var width := line_width
	if state == State.WARNING:
		color = Color(1.0, 0.76, 0.22, 0.48 + pulse * 0.28)
	elif state == State.DANGER:
		color = Color(1.0, 0.18, 0.28, 0.7 + pulse * 0.3)
		width += pulse * 3.0
	var x := start_x
	while x < end_x:
		var dash_end := minf(x + dash_length, end_x)
		draw_line(Vector2(x, line_y), Vector2(dash_end, line_y), color, width, true)
		x += dash_length + gap_length
