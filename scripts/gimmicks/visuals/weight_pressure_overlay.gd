class_name WeightPressureOverlay
extends Node2D

var bounds := Rect2()
var plate_ratio := 0.38
var left_weight := 0.0
var right_weight := 0.0
var required_weight := 25.0
var target_plate := 0
var turns_remaining := 0
var result_text := ""


func show_state(board_bounds: Rect2, width_ratio: float, left_total: float, right_total: float, required: float, target: int, turns: int, result: String) -> void:
	bounds = board_bounds
	plate_ratio = width_ratio
	left_weight = left_total
	right_weight = right_total
	required_weight = required
	target_plate = target
	turns_remaining = turns
	result_text = result
	queue_redraw()


func _draw() -> void:
	var plate_height: float = 62.0
	var plate_width: float = bounds.size.x * plate_ratio
	var left_rect := Rect2(Vector2(bounds.position.x, bounds.end.y - plate_height), Vector2(plate_width, plate_height))
	var right_rect := Rect2(Vector2(bounds.end.x - plate_width, bounds.end.y - plate_height), Vector2(plate_width, plate_height))
	_draw_plate(left_rect, "LEFT", left_weight, target_plate == 0 or target_plate == 2)
	_draw_plate(right_rect, "RIGHT", right_weight, target_plate == 1 or target_plate == 2)
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 28.0), "NEXT: %s · %d턴" % [_target_name(), turns_remaining], HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 20, Color("#ffd166"))
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 80.0, bounds.get_center().y - 34.0), Vector2(bounds.size.x - 160.0, 68.0)), Color(0.03, 0.07, 0.14, 0.88), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 8.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 24, Color("#ffd166"))


func _draw_plate(plate_rect: Rect2, plate_name: String, current: float, targeted: bool) -> void:
	var active_now: bool = current >= required_weight
	var plate_color: Color = Color("#70ff9b") if active_now else Color("#5f8db8")
	draw_rect(plate_rect, Color(plate_color, 0.24), true)
	draw_rect(plate_rect, Color("#ffd166") if targeted else plate_color, false, 4.0 if targeted else 2.0)
	var label_text: String = "%s  %.1f / %.1f  %s" % [plate_name, current, required_weight, "ACTIVE" if active_now else "INACTIVE"]
	draw_string(ThemeDB.fallback_font, Vector2(plate_rect.position.x, plate_rect.position.y + 36.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, plate_rect.size.x, 16, plate_color)


func _target_name() -> String:
	if target_plate == 1:
		return "RIGHT"
	if target_plate == 2:
		return "BOTH"
	return "LEFT"

