class_name StackCoverLaserOverlay
extends Node2D

var bounds := Rect2()
var cover_line_y := 0.0
var cover_states: Array[bool] = [false, false, false]
var direction := 1
var piercing := false
var turns_remaining := 0
var flash_zones: Array[int] = []
var result_text := ""


func show_state(board_bounds: Rect2, line_y: float, states: Array[bool], laser_direction: int, is_piercing: bool, turns: int, hit_zones: Array[int], result: String) -> void:
	bounds = board_bounds
	cover_line_y = line_y
	for zone_index in 3:
		cover_states[zone_index] = states[zone_index]
	direction = laser_direction
	piercing = is_piercing
	turns_remaining = turns
	flash_zones = hit_zones.duplicate()
	result_text = result
	queue_redraw()


func _draw() -> void:
	var zone_width: float = bounds.size.x / 3.0
	draw_dashed_line(Vector2(bounds.position.x, cover_line_y), Vector2(bounds.end.x, cover_line_y), Color("#ffd166"), 3.0, 10.0)
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x + 8.0, cover_line_y - 8.0), "COVER LINE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#ffd166"))
	for zone_index in 3:
		var zone_rect := Rect2(Vector2(bounds.position.x + zone_width * zone_index, bounds.position.y), Vector2(zone_width, bounds.size.y))
		if zone_index > 0:
			draw_dashed_line(Vector2(zone_rect.position.x, bounds.position.y), Vector2(zone_rect.position.x, bounds.end.y), Color(0.65, 0.8, 1.0, 0.25), 2.0, 9.0)
		if flash_zones.has(zone_index):
			draw_rect(zone_rect, Color(1.0, 0.25, 0.18, 0.28), true)
		var state_color: Color = Color("#70ff9b") if cover_states[zone_index] else Color("#8795a1")
		var label_text: String = "%s: %s" % [["LEFT", "CENTER", "RIGHT"][zone_index], "COVER" if cover_states[zone_index] else "OPEN"]
		draw_string(ThemeDB.fallback_font, Vector2(zone_rect.position.x, bounds.position.y + 56.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, zone_width, 16, state_color)
	var laser_y: float = cover_line_y - 20.0
	var laser_color: Color = Color("#ff3b6b") if piercing else Color("#ff8c42")
	draw_line(Vector2(bounds.position.x, laser_y), Vector2(bounds.end.x, laser_y), Color(laser_color, 0.55), 5.0)
	var header: String = "%s · %s · %d턴" % ["PIERCING" if piercing else "NORMAL", "LEFT >>> RIGHT" if direction > 0 else "RIGHT <<< LEFT", turns_remaining]
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 26.0), header, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 18, laser_color)
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 80.0, bounds.get_center().y - 34.0), Vector2(bounds.size.x - 160.0, 68.0)), Color(0.03, 0.07, 0.14, 0.88), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 8.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 22, Color("#ffd166"))

