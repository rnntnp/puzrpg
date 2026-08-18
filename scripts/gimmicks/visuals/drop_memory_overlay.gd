class_name DropMemoryOverlay
extends Node2D

var bounds := Rect2()
var memory: Array[int] = []
var enemy_mode := 0
var turns_remaining := 0
var attacking_zone := -1
var result_text := ""


func show_state(board_bounds: Rect2, memory_values: Array[int], mode: int, turns: int, attack_zone: int, result: String) -> void:
	bounds = board_bounds
	memory = memory_values.duplicate()
	enemy_mode = mode
	turns_remaining = turns
	attacking_zone = attack_zone
	result_text = result
	queue_redraw()


func _draw() -> void:
	var zone_width: float = bounds.size.x / 3.0
	for zone_index in 3:
		var zone_rect := Rect2(Vector2(bounds.position.x + zone_width * zone_index, bounds.position.y), Vector2(zone_width, bounds.size.y))
		if zone_index > 0:
			draw_dashed_line(Vector2(zone_rect.position.x, bounds.position.y), Vector2(zone_rect.position.x, bounds.end.y), Color(0.65, 0.8, 1.0, 0.28), 2.0, 10.0)
		if attacking_zone == zone_index:
			draw_rect(zone_rect, Color(1.0, 0.25, 0.2, 0.30), true)
		draw_string(ThemeDB.fallback_font, Vector2(zone_rect.position.x, bounds.position.y + 58.0), _zone_name(zone_index), HORIZONTAL_ALIGNMENT_CENTER, zone_width, 16, Color("#b8d8ff"))
		var order_y: float = bounds.position.y + 82.0
		for memory_index in memory.size():
			if memory[memory_index] == zone_index:
				draw_circle(Vector2(zone_rect.get_center().x - 28.0 + memory_index * 28.0, order_y), 11.0, Color("#ffd166"))
				draw_string(ThemeDB.fallback_font, Vector2(zone_rect.get_center().x - 39.0 + memory_index * 28.0, order_y + 6.0), str(memory_index + 1), HORIZONTAL_ALIGNMENT_CENTER, 22.0, 14, Color("#14213d"))
	var sequence: String = _sequence_text()
	var prefix: String = "REPLAY" if enemy_mode == 2 else "MEMORY"
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 28.0), "%s: %s · %d턴" % [prefix, sequence, turns_remaining], HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 19, Color("#ffd166"))
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 88.0, bounds.get_center().y - 32.0), Vector2(bounds.size.x - 176.0, 64.0)), Color(0.03, 0.07, 0.14, 0.88), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 8.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 21, Color("#ffb86c"))


func _sequence_text() -> String:
	var entries: Array[String] = []
	for zone_index in memory:
		entries.append(_zone_short_name(zone_index))
	if enemy_mode == 2:
		while entries.size() < 3:
			entries.append("?")
	return " → ".join(entries) if not entries.is_empty() else "—"


func _zone_name(zone_index: int) -> String:
	if zone_index == 0:
		return "LEFT"
	if zone_index == 1:
		return "CENTER"
	return "RIGHT"


func _zone_short_name(zone_index: int) -> String:
	if zone_index == 0:
		return "L"
	if zone_index == 1:
		return "C"
	return "R"

