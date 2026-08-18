class_name StageCensusOverlay
extends Node2D

const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var target_ranges: Array[Vector2i] = []
var target_deltas: Array[int] = []
var left_counts: Array[int] = []
var right_counts: Array[int] = []
var left_positions: Array[Vector2] = []
var right_positions: Array[Vector2] = []
var minimum_total := 2
var turns_remaining := 0
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	ranges: Array[Vector2i],
	deltas: Array[int],
	left_values: Array[int],
	right_values: Array[int],
	left_ball_positions: Array[Vector2],
	right_ball_positions: Array[Vector2],
	required_total: int,
	turns: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	target_ranges.assign(ranges)
	target_deltas.assign(deltas)
	left_counts.assign(left_values)
	right_counts.assign(right_values)
	left_positions.assign(left_ball_positions)
	right_positions.assign(right_ball_positions)
	minimum_total = maxi(1, required_total)
	turns_remaining = maxi(0, turns)
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	var center_x: float = board_bounds.get_center().x
	draw_rect(Rect2(board_bounds.position, Vector2(board_bounds.size.x * 0.5, board_bounds.size.y)), Color(0.25, 0.76, 1.0, 0.055), true)
	draw_rect(Rect2(Vector2(center_x, board_bounds.position.y), Vector2(board_bounds.size.x * 0.5, board_bounds.size.y)), Color(1.0, 0.48, 0.62, 0.055), true)
	draw_line(Vector2(center_x, board_bounds.position.y), Vector2(center_x, board_bounds.end.y), Color(0.86, 0.94, 1.0, 0.58), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.position.y + 29.0), "STAGE CENSUS · LEFT - RIGHT · %d TURN" % turns_remaining, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 19, Color("#d7f5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x + 18.0, board_bounds.position.y + 55.0), "LEFT", HORIZONTAL_ALIGNMENT_LEFT, 110.0, 15, Color("#70d7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(board_bounds.end.x - 128.0, board_bounds.position.y + 55.0), "RIGHT", HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 15, Color("#ff8fab"))
	var row_width: float = minf(430.0, board_bounds.size.x - 56.0)
	var row_x: float = board_bounds.get_center().x - row_width * 0.5
	for target_index in target_ranges.size():
		var row_y: float = board_bounds.position.y + 72.0 + float(target_index) * 76.0
		var row_rect: Rect2 = Rect2(Vector2(row_x, row_y), Vector2(row_width, 66.0))
		var current_delta: int = left_counts[target_index] - right_counts[target_index]
		var total: int = left_counts[target_index] + right_counts[target_index]
		var matches: bool = total >= minimum_total and current_delta == target_deltas[target_index]
		var row_color: Color = Color("#70ff9b") if matches else Color("#ffd166")
		draw_rect(row_rect, Color(0.04, 0.09, 0.16, 0.88), true)
		draw_rect(row_rect, row_color, false, 2.5)
		draw_string(ThemeDB.fallback_font, Vector2(row_rect.position.x + 12.0, row_rect.position.y + 24.0), _stage_label(target_ranges[target_index]), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 18, Color("#e8f7ff"))
		draw_string(ThemeDB.fallback_font, Vector2(row_rect.position.x + 94.0, row_rect.position.y + 24.0), "L %d" % left_counts[target_index], HORIZONTAL_ALIGNMENT_CENTER, 72.0, 18, Color("#70d7ff"))
		draw_string(ThemeDB.fallback_font, Vector2(row_rect.position.x + row_rect.size.x - 166.0, row_rect.position.y + 24.0), "R %d" % right_counts[target_index], HORIZONTAL_ALIGNMENT_CENTER, 72.0, 18, Color("#ff8fab"))
		draw_string(ThemeDB.fallback_font, Vector2(row_rect.position.x, row_rect.position.y + 52.0), "Δ %s  →  %s · TOTAL %d/%d" % [_signed_value(current_delta), _signed_value(target_deltas[target_index]), total, minimum_total], HORIZONTAL_ALIGNMENT_CENTER, row_rect.size.x, 16, row_color)
	for target_ball_position: Vector2 in left_positions:
		draw_arc(target_ball_position, 26.0, 0.0, TAU, 28, Color("#70d7ff"), 4.0, true)
	for target_ball_position: Vector2 in right_positions:
		draw_arc(target_ball_position, 26.0, 0.0, TAU, 28, Color("#ff8fab"), 4.0, true)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect: Rect2 = Rect2(Vector2(board_bounds.position.x + 58.0, board_bounds.get_center().y - 38.0), Vector2(board_bounds.size.x - 116.0, 76.0))
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.92), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 22, feedback_color)


func _stage_label(stage_range: Vector2i) -> String:
	return "S%d" % stage_range.x if stage_range.x == stage_range.y else "S%d-%d" % [stage_range.x, stage_range.y]


func _signed_value(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
