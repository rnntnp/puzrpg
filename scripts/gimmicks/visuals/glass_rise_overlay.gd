class_name GlassRiseOverlay
extends Node2D

var bounds := Rect2()
var rects: Array[Rect2] = []
var names: Array[String] = []
var states: Array[int] = []
var loads: Array[int] = []
var crack_threshold := 0
var destroy_thresholds: Array[int] = []
var result := ""

func show_state(board_bounds: Rect2, glass_rects: Array[Rect2], glass_names: Array[String], glass_states: Array[int], glass_loads: Array[int], crack_value: int, destroy_values: Array[int], result_text: String) -> void:
	bounds = board_bounds
	rects = glass_rects.duplicate()
	names = glass_names.duplicate()
	states = glass_states.duplicate()
	loads = glass_loads.duplicate()
	crack_threshold = crack_value
	destroy_thresholds = destroy_values.duplicate()
	result = result_text
	queue_redraw()

func _draw() -> void:
	for index in rects.size():
		var rect := rects[index]
		if rect.size == Vector2.ZERO: continue
		var state: int = states[index]
		var color := Color("#71e5ff") if state == 0 else (Color("#ffc857") if state == 1 else Color("#ff667a"))
		if state == 2:
			draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, 3.0, 8.0)
		else:
			draw_rect(rect, Color(color, 0.42), true)
			draw_rect(rect, color, false, 3.0)
		var state_text := "DESTROYED" if state == 2 else ("CRACKED" if state == 1 else "NORMAL")
		var slot_name: String = names[index] if index < names.size() else "GLASS"
		var destroy_threshold: int = destroy_thresholds[index] if index < destroy_thresholds.size() else 0
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y - 10.0), "%s %s · %d/%d" % [slot_name, state_text, loads[index], destroy_threshold], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, color)
