class_name BallCountContractOverlay
extends Node2D

const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var baseline_counts: Array[int] = [0, 0, 0]
var current_counts: Array[int] = [0, 0, 0]
var target_counts: Array[int] = [-1, -1, -1]
var turns_remaining := 0
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	baselines: Array[int],
	currents: Array[int],
	targets: Array[int],
	turns: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	baseline_counts.assign(baselines)
	current_counts.assign(currents)
	target_counts.assign(targets)
	turns_remaining = maxi(0, turns)
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	var section_width: float = board_bounds.size.x / 3.0
	for zone in 3:
		var section_rect := Rect2(
			Vector2(board_bounds.position.x + section_width * float(zone), board_bounds.position.y),
			Vector2(section_width, board_bounds.size.y)
		)
		var is_required: bool = target_counts[zone] >= 0
		var matches: bool = not is_required or current_counts[zone] == target_counts[zone]
		var state_color: Color = _state_color(zone)
		if is_required:
			draw_rect(section_rect, Color(state_color, 0.13), true)
			draw_rect(section_rect.grow(-3.0), state_color, false, 4.0)
		else:
			draw_rect(section_rect, Color(0.02, 0.06, 0.12, 0.05), true)
		if zone > 0:
			draw_line(
				Vector2(section_rect.position.x, section_rect.position.y),
				Vector2(section_rect.position.x, section_rect.end.y),
				Color(0.72, 0.9, 1.0, 0.4),
				2.0
			)
		var label_y: float = board_bounds.position.y + 64.0
		draw_string(
			ThemeDB.fallback_font,
			Vector2(section_rect.position.x, label_y),
			_zone_name(zone),
			HORIZONTAL_ALIGNMENT_CENTER,
			section_width,
			16,
			Color("#d7f5ff")
		)
		var count_text: String = "%d / %s" % [current_counts[zone], _target_text(zone)]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(section_rect.position.x, label_y + 29.0),
			count_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			section_width,
			22,
			state_color
		)
		var addition_text: String = "ANY" if not is_required else "BASE %d  +%d" % [baseline_counts[zone], target_counts[zone] - baseline_counts[zone]]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(section_rect.position.x, label_y + 54.0),
			addition_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			section_width,
			14,
			Color("#c8d7e8")
		)
		if is_required and matches:
			draw_circle(Vector2(section_rect.get_center().x, label_y + 78.0), 5.0, Color("#70ff9b"))

	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 30.0),
		"BALL COUNT CONTRACT · %d TURN" % turns_remaining,
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		20,
		Color("#ffd166")
	)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect := Rect2(
			Vector2(board_bounds.position.x + 72.0, board_bounds.get_center().y - 38.0),
			Vector2(board_bounds.size.x - 144.0, 76.0)
		)
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.88), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			24,
			feedback_color
		)


func _state_color(zone: int) -> Color:
	if target_counts[zone] < 0:
		return Color("#9fb3c8")
	if current_counts[zone] == target_counts[zone]:
		return Color("#70ff9b")
	if current_counts[zone] > target_counts[zone]:
		return Color("#ff6b6b")
	return Color("#ffd166")


func _target_text(zone: int) -> String:
	return "ANY" if target_counts[zone] < 0 else str(target_counts[zone])


func _zone_name(zone: int) -> String:
	match clampi(zone, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"
