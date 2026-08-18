class_name MergeLedgerOverlay
extends Node2D

const MODE_GLOBAL := 0
const MODE_ACTIVE_SIDE := 1
const MODE_DUAL_SIDE := 2
const SIDE_LEFT := 0
const SIDE_RIGHT := 1
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var enemy_mode := MODE_GLOBAL
var active_side := SIDE_LEFT
var global_total := 0
var left_total := 0
var right_total := 0
var global_target := -1
var left_target := -1
var right_target := -1
var turns_remaining := 0
var recent_result_stage := -1
var recent_side := -1
var recent_counted := false
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	mode: int,
	selected_side: int,
	global_value: int,
	left_value: int,
	right_value: int,
	global_goal: int,
	left_goal: int,
	right_goal: int,
	turns: int,
	recent_stage: int,
	recent_origin_side: int,
	was_counted: bool,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	enemy_mode = mode
	active_side = selected_side
	global_total = global_value
	left_total = left_value
	right_total = right_value
	global_target = global_goal
	left_target = left_goal
	right_target = right_goal
	turns_remaining = maxi(0, turns)
	recent_result_stage = recent_stage
	recent_side = recent_origin_side
	recent_counted = was_counted
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	if enemy_mode == MODE_GLOBAL:
		draw_rect(board_bounds, Color(0.18, 0.62, 0.95, 0.06), true)
		_draw_ledger_card(board_bounds.get_center().x, board_bounds.position.y + 78.0, "GLOBAL", global_total, global_target, true)
	else:
		var half_width: float = board_bounds.size.x * 0.5
		var center_x: float = board_bounds.get_center().x
		draw_line(Vector2(center_x, board_bounds.position.y), Vector2(center_x, board_bounds.end.y), Color(0.8, 0.92, 1.0, 0.55), 3.0)
		var left_active: bool = enemy_mode == MODE_DUAL_SIDE or active_side == SIDE_LEFT
		var right_active: bool = enemy_mode == MODE_DUAL_SIDE or active_side == SIDE_RIGHT
		draw_rect(Rect2(board_bounds.position, Vector2(half_width, board_bounds.size.y)), Color(0.25, 0.76, 1.0, 0.08 if left_active else 0.025), true)
		draw_rect(Rect2(Vector2(center_x, board_bounds.position.y), Vector2(half_width, board_bounds.size.y)), Color(1.0, 0.55, 0.68, 0.08 if right_active else 0.025), true)
		_draw_ledger_card(board_bounds.position.x + half_width * 0.5, board_bounds.position.y + 78.0, "LEFT", left_total, left_target, left_active)
		_draw_ledger_card(center_x + half_width * 0.5, board_bounds.position.y + 78.0, "RIGHT", right_total, right_target, right_active)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 29.0),
		"MERGE LEDGER · %d TURN" % turns_remaining,
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		20,
		Color("#d7f5ff")
	)
	if recent_result_stage >= 0:
		var recent_color: Color = Color("#70ff9b") if recent_counted else Color("#8a9baa")
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, board_bounds.position.y + 147.0),
			"LAST · %s · STAGE %d · %s" % [_side_name(recent_side), recent_result_stage, "COUNTED" if recent_counted else "IGNORED"],
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			17,
			recent_color
		)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect := Rect2(
			Vector2(board_bounds.position.x + 60.0, board_bounds.get_center().y - 38.0),
			Vector2(board_bounds.size.x - 120.0, 76.0)
		)
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.9), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			22,
			feedback_color
		)


func _draw_ledger_card(center_x: float, center_y: float, label: String, total: int, target: int, is_active: bool) -> void:
	var card_width := 190.0 if enemy_mode == MODE_GLOBAL else 150.0
	var card_rect := Rect2(Vector2(center_x - card_width * 0.5, center_y - 31.0), Vector2(card_width, 70.0))
	var state_color: Color = _ledger_color(total, target) if is_active else Color("#64788c")
	draw_rect(card_rect, Color(state_color, 0.17 if is_active else 0.07), true)
	draw_rect(card_rect, state_color, false, 3.0 if is_active else 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 23.0), label if is_active else "%s · IGNORED" % label, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 15, state_color)
	var value_text: String = "%d / %d" % [total, target] if is_active else "—"
	draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 51.0), value_text, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 24, Color.WHITE)
	if is_active:
		var remaining: int = target - total
		var remaining_text: String = "EXACT" if remaining == 0 else ("OVER %d" % -remaining if remaining < 0 else "REMAIN %d" % remaining)
		draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 68.0), remaining_text, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 12, state_color)


func _ledger_color(total: int, target: int) -> Color:
	if total == target:
		return Color("#70ff9b")
	if total > target:
		return Color("#ff6b6b")
	return Color("#ffd166")


func _side_name(side: int) -> String:
	return "LEFT" if side == SIDE_LEFT else "RIGHT"

