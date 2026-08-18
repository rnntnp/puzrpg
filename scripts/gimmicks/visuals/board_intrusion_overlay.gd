class_name BoardIntrusionOverlay
extends Node2D

const SIDE_LEFT := -1
const HEIGHT_HIGH := 1

var bounds := Rect2()
var arm_specs: Array[Vector2i] = []
var target_centers: Array[Vector2] = []
var body_positions: Array[Vector2] = []
var arm_size := Vector2.ZERO
var arms_active := false
var telegraph_remaining := 0
var hold_remaining := 0
var result_text := ""


func show_state(board_bounds: Rect2, spec_values: Array[Vector2i], target_values: Array[Vector2], position_values: Array[Vector2], current_arm_size: Vector2, active_now: bool, telegraph_turns: int, hold_turns: int, result: String) -> void:
	bounds = board_bounds
	arm_specs = spec_values.duplicate()
	target_centers = target_values.duplicate()
	body_positions = position_values.duplicate()
	arm_size = current_arm_size
	arms_active = active_now
	telegraph_remaining = telegraph_turns
	hold_remaining = hold_turns
	result_text = result
	queue_redraw()


func _draw() -> void:
	var draw_size: Vector2 = arm_size
	if draw_size == Vector2.ZERO:
		draw_size = Vector2(bounds.size.x * 0.36, bounds.size.y * 0.065)
	for spec_index in arm_specs.size():
		var spec: Vector2i = arm_specs[spec_index]
		var target_center: Vector2 = target_centers[spec_index] if spec_index < target_centers.size() else bounds.get_center()
		var preview_rect := Rect2(target_center - draw_size * 0.5, draw_size)
		if not arms_active:
			draw_rect(preview_rect, Color(0.8, 0.35, 0.95, 0.14), true)
			draw_dashed_line(preview_rect.position, Vector2(preview_rect.end.x, preview_rect.position.y), Color("#d783ff"), 2.0, 8.0)
			draw_dashed_line(Vector2(preview_rect.position.x, preview_rect.end.y), preview_rect.end, Color("#d783ff"), 2.0, 8.0)
		if spec_index < body_positions.size():
			var actual_rect := Rect2(body_positions[spec_index] - draw_size * 0.5, draw_size)
			draw_rect(actual_rect, Color(0.46, 0.18, 0.65, 0.78), true)
			draw_rect(actual_rect, Color("#f0b8ff"), false, 3.0)
			draw_string(ThemeDB.fallback_font, Vector2(actual_rect.position.x, actual_rect.get_center().y + 6.0), "ARM", HORIZONTAL_ALIGNMENT_CENTER, actual_rect.size.x, 16, Color.WHITE)
	var header: String = "ARMS ACTIVE · RETRACT %d턴" % hold_remaining if arms_active else "NEXT INTRUSION · %d턴" % telegraph_remaining
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 28.0), header, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 19, Color("#f0b8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 54.0), _specs_text(), HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 16, Color("#ffd166"))
	if not result_text.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 82.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 17, Color.WHITE)


func _specs_text() -> String:
	var entries: Array[String] = []
	for spec in arm_specs:
		entries.append("%s %s" % ["LEFT" if spec.x == SIDE_LEFT else "RIGHT", "HIGH" if spec.y == HEIGHT_HIGH else "LOW"])
	return " + ".join(entries)
