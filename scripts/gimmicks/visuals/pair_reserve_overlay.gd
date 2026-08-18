class_name PairReserveOverlay
extends Node2D

const MODE_GLOBAL_ONE := 0
const MODE_GLOBAL_MULTI := 1
const MODE_SPLIT := 2
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var enemy_mode := MODE_GLOBAL_ONE
var global_pair_stages: Array[int] = []
var left_pair_stages: Array[int] = []
var right_pair_stages: Array[int] = []
var excluded_global_stages: Array[int] = []
var excluded_left_stages: Array[int] = []
var excluded_right_stages: Array[int] = []
var qualified_positions: Array[Vector2] = []
var excluded_positions: Array[Vector2] = []
var required_pair_count := 1
var turns_remaining := 0
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	mode: int,
	global_pairs: Array[int],
	left_pairs: Array[int],
	right_pairs: Array[int],
	global_excluded: Array[int],
	left_excluded: Array[int],
	right_excluded: Array[int],
	pair_positions: Array[Vector2],
	excluded_pair_positions: Array[Vector2],
	required_count: int,
	turns: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	enemy_mode = mode
	global_pair_stages.assign(global_pairs)
	left_pair_stages.assign(left_pairs)
	right_pair_stages.assign(right_pairs)
	excluded_global_stages.assign(global_excluded)
	excluded_left_stages.assign(left_excluded)
	excluded_right_stages.assign(right_excluded)
	qualified_positions.assign(pair_positions)
	excluded_positions.assign(excluded_pair_positions)
	required_pair_count = maxi(1, required_count)
	turns_remaining = maxi(0, turns)
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	if enemy_mode == MODE_SPLIT:
		var center_x: float = board_bounds.get_center().x
		draw_line(Vector2(center_x, board_bounds.position.y), Vector2(center_x, board_bounds.end.y), Color(0.8, 0.92, 1.0, 0.52), 3.0)
		draw_rect(Rect2(board_bounds.position, Vector2(board_bounds.size.x * 0.5, board_bounds.size.y)), Color(0.25, 0.76, 1.0, 0.045), true)
		draw_rect(Rect2(Vector2(center_x, board_bounds.position.y), Vector2(board_bounds.size.x * 0.5, board_bounds.size.y)), Color(1.0, 0.55, 0.68, 0.045), true)
		_draw_stage_card(board_bounds.position.x + board_bounds.size.x * 0.25, "LEFT", left_pair_stages, excluded_left_stages)
		_draw_stage_card(board_bounds.position.x + board_bounds.size.x * 0.75, "RIGHT", right_pair_stages, excluded_right_stages)
	else:
		_draw_stage_card(board_bounds.get_center().x, "GLOBAL · NEED %d" % required_pair_count, global_pair_stages, excluded_global_stages)
	for ball_position: Vector2 in qualified_positions:
		draw_circle(ball_position, 24.0, Color(0.4, 1.0, 0.62, 0.12))
		draw_arc(ball_position, 26.0, 0.0, TAU, 28, Color("#70ff9b"), 4.0, true)
	for ball_position: Vector2 in excluded_positions:
		draw_circle(ball_position, 24.0, Color(0.55, 0.62, 0.68, 0.08))
		draw_arc(ball_position, 26.0, 0.0, TAU, 28, Color("#7d8b99"), 3.0, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 29.0),
		"PAIR RESERVE · %d TURN" % turns_remaining,
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		20,
		Color("#d7f5ff")
	)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect := Rect2(
			Vector2(board_bounds.position.x + 58.0, board_bounds.get_center().y - 38.0),
			Vector2(board_bounds.size.x - 116.0, 76.0)
		)
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.9), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 22, feedback_color)


func _draw_stage_card(center_x: float, label: String, stages: Array[int], excluded: Array[int]) -> void:
	var card_width := 250.0 if enemy_mode != MODE_SPLIT else 210.0
	var card_rect := Rect2(Vector2(center_x - card_width * 0.5, board_bounds.position.y + 46.0), Vector2(card_width, 76.0))
	draw_rect(card_rect, Color(0.04, 0.1, 0.18, 0.82), true)
	draw_rect(card_rect, Color("#63e6ff"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 24.0), label, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 15, Color("#d7f5ff"))
	draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 49.0), "PAIRS %s" % _stage_list(stages), HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 17, Color("#70ff9b"))
	draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 69.0), "EXCLUDED %s" % _stage_list(excluded), HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 12, Color("#8a9baa"))


func _stage_list(stages: Array[int]) -> String:
	if stages.is_empty():
		return "—"
	var entries: Array[String] = []
	for stage: int in stages:
		entries.append("S%d" % stage)
	return ", ".join(entries)
