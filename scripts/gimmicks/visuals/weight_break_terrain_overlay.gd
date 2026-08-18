class_name WeightBreakTerrainOverlay
extends Node2D

var bounds := Rect2()
var floor_rects: Array[Rect2] = []
var floor_names: Array[String] = []
var floor_loads: Array[float] = []
var break_weights: Array[float] = []
var floor_broken: Array[bool] = []
var result_text := ""


func show_state(board_bounds: Rect2, rect_values: Array[Rect2], name_values: Array[String], load_values: Array[float], break_values: Array[float], broken_values: Array[bool], result: String) -> void:
	bounds = board_bounds
	floor_rects = rect_values.duplicate()
	floor_names = name_values.duplicate()
	floor_loads = load_values.duplicate()
	break_weights = break_values.duplicate()
	floor_broken = broken_values.duplicate()
	result_text = result
	queue_redraw()


func _draw() -> void:
	for floor_index in floor_rects.size():
		var floor_rect: Rect2 = floor_rects[floor_index]
		if floor_broken[floor_index]:
			draw_dashed_line(floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), Color(0.8, 0.35, 0.35, 0.42), 3.0, 9.0)
			draw_string(ThemeDB.fallback_font, Vector2(floor_rect.position.x, floor_rect.position.y - 8.0), "%s · BROKEN" % floor_names[floor_index], HORIZONTAL_ALIGNMENT_CENTER, floor_rect.size.x, 16, Color("#ff6b6b"))
			continue
		var ratio: float = floor_loads[floor_index] / maxf(0.01, break_weights[floor_index])
		var floor_color: Color = Color("#ff5d5d") if ratio >= 0.85 else (Color("#ffd166") if ratio >= 0.60 else Color("#6dd5ed"))
		draw_rect(floor_rect, Color(floor_color, 0.55), true)
		draw_rect(floor_rect, floor_color, false, 3.0)
		var state_text: String = "CRITICAL" if ratio >= 0.85 else ("WARNING" if ratio >= 0.60 else "SAFE")
		draw_string(ThemeDB.fallback_font, Vector2(floor_rect.position.x, floor_rect.position.y - 10.0), "%s %.1f / %.1f · %s" % [floor_names[floor_index], floor_loads[floor_index], break_weights[floor_index], state_text], HORIZONTAL_ALIGNMENT_CENTER, floor_rect.size.x, 16, floor_color)
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 90.0, bounds.get_center().y - 34.0), Vector2(bounds.size.x - 180.0, 68.0)), Color(0.03, 0.07, 0.14, 0.88), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 8.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 24, Color("#ffb86c"))

