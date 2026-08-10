class_name DangerLine
extends Node2D

@export var start_x := 102.0
@export var end_x := 618.0
@export var line_y := 230.0
@export var dash_length := 16.0
@export var gap_length := 11.0
@export var line_width := 4.0
@export var line_color := Color(1.0, 0.25, 0.32, 0.72)


func _ready() -> void:
	queue_redraw()


func configure(left: float, right: float, y_position: float) -> void:
	start_x = left
	end_x = right
	line_y = y_position
	queue_redraw()


func _draw() -> void:
	var x := start_x
	while x < end_x:
		var dash_end := minf(x + dash_length, end_x)
		draw_line(Vector2(x, line_y), Vector2(dash_end, line_y), line_color, line_width, true)
		x += dash_length + gap_length
