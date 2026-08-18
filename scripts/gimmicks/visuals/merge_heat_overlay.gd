class_name MergeHeatOverlay
extends Node2D

var bounds := Rect2()
var heat := 0
var maximum_heat := 100
var warm_threshold := 30
var hot_threshold := 70
var damage_multiplier := 1.0
var check_name := "VENT"
var turns_remaining := 0
var result_text := ""


func show_state(board_bounds: Rect2, heat_value: int, maximum: int, warm_start: int, hot_start: int, multiplier: float, next_check: String, turns: int, result: String) -> void:
	bounds = board_bounds
	heat = heat_value
	maximum_heat = maximum
	warm_threshold = warm_start
	hot_threshold = hot_start
	damage_multiplier = multiplier
	check_name = next_check
	turns_remaining = turns
	result_text = result
	queue_redraw()


func _draw() -> void:
	var gauge_rect := Rect2(Vector2(bounds.position.x + 70.0, bounds.position.y + 42.0), Vector2(bounds.size.x - 140.0, 24.0))
	draw_rect(gauge_rect, Color(0.04, 0.09, 0.16, 0.82), true)
	var ratio: float = float(heat) / float(maxi(1, maximum_heat))
	var fill_rect := Rect2(gauge_rect.position, Vector2(gauge_rect.size.x * ratio, gauge_rect.size.y))
	draw_rect(fill_rect, _heat_color(), true)
	draw_rect(gauge_rect, Color("#d7e9ff"), false, 2.0)
	var heat_text: String = "HEAT %d / %d · %s · MERGE ×%.2f" % [heat, maximum_heat, _heat_state(), damage_multiplier]
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 30.0), heat_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 18, _heat_color())
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 90.0), "NEXT: %s · %d턴" % [check_name, turns_remaining], HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 19, Color("#ffd166"))
	if not result_text.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 118.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 20, Color("#ffffff"))


func _heat_state() -> String:
	if heat >= hot_threshold:
		return "HOT"
	if heat >= warm_threshold:
		return "WARM"
	return "COOL"


func _heat_color() -> Color:
	if heat >= hot_threshold:
		return Color("#ff4d4d")
	if heat >= warm_threshold:
		return Color("#ffb347")
	return Color("#59c3ff")

