class_name MergeSpectrumOverlay
extends Node2D

const MODE_ANY_TWO := 0
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var collected: Array[bool] = [false, false, false]
var required: Array[bool] = [true, true, true]
var enemy_mode := MODE_ANY_TWO
var teach_required_count := 2
var low_maximum_stage := 3
var mid_maximum_stage := 4
var turns_remaining := 0
var recent_result_stage := -1
var recent_category := -1
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	collected_categories: Array[bool],
	required_categories: Array[bool],
	mode: int,
	teach_count: int,
	low_maximum: int,
	mid_maximum: int,
	turns: int,
	recent_stage: int,
	recent_band: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	collected.assign(collected_categories)
	required.assign(required_categories)
	enemy_mode = mode
	teach_required_count = clampi(teach_count, 2, 3)
	low_maximum_stage = maxi(2, low_maximum)
	mid_maximum_stage = maxi(low_maximum_stage + 1, mid_maximum)
	turns_remaining = maxi(0, turns)
	recent_result_stage = recent_stage
	recent_category = recent_band
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	var gap := 12.0
	var available_width: float = board_bounds.size.x - 48.0
	var card_width: float = (available_width - gap * 2.0) / 3.0
	var start_x: float = board_bounds.position.x + 24.0
	var card_y: float = board_bounds.position.y + 44.0
	for category in 3:
		var card_rect := Rect2(
			Vector2(start_x + float(category) * (card_width + gap), card_y),
			Vector2(card_width, 82.0)
		)
		var is_needed: bool = enemy_mode == MODE_ANY_TWO or required[category]
		var is_collected: bool = collected[category]
		var category_color: Color = _category_color(category)
		var border_color: Color = Color("#70ff9b") if is_collected else (category_color if is_needed else Color("#64788c"))
		draw_rect(card_rect, Color(border_color, 0.18 if is_needed else 0.07), true)
		draw_rect(card_rect, border_color, false, 3.0 if is_needed else 1.5)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(card_rect.position.x, card_rect.position.y + 28.0),
			_category_name(category),
			HORIZONTAL_ALIGNMENT_CENTER,
			card_rect.size.x,
			19,
			border_color
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(card_rect.position.x, card_rect.position.y + 53.0),
			_stage_range_text(category),
			HORIZONTAL_ALIGNMENT_CENTER,
			card_rect.size.x,
			15,
			Color.WHITE
		)
		var state_label: String = "COLLECTED" if is_collected else ("NEEDED" if is_needed else "OPTIONAL")
		draw_string(
			ThemeDB.fallback_font,
			Vector2(card_rect.position.x, card_rect.position.y + 74.0),
			state_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			card_rect.size.x,
			13,
			border_color
		)

	var headline: String = "ANY %d DISTINCT" % teach_required_count if enemy_mode == MODE_ANY_TWO else "FILL ALL NEEDED BANDS"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 28.0),
		"MERGE SPECTRUM · %s · %d TURN" % [headline, turns_remaining],
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		18,
		Color("#d7f5ff")
	)
	if recent_result_stage >= 0:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, card_y + 112.0),
			"LAST MERGE · STAGE %d · %s" % [recent_result_stage, _category_name(recent_category)],
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			18,
			_category_color(recent_category)
		)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect := Rect2(
			Vector2(board_bounds.position.x + 56.0, board_bounds.get_center().y - 38.0),
			Vector2(board_bounds.size.x - 112.0, 76.0)
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


func _stage_range_text(category: int) -> String:
	if category == 0:
		return "STAGE 2-%d" % low_maximum_stage
	if category == 1:
		return "STAGE %d-%d" % [low_maximum_stage + 1, mid_maximum_stage]
	return "STAGE %d+" % (mid_maximum_stage + 1)


func _category_name(category: int) -> String:
	match clampi(category, 0, 2):
		0: return "LOW"
		1: return "MID"
		_: return "HIGH"


func _category_color(category: int) -> Color:
	match clampi(category, 0, 2):
		0: return Color("#63e6ff")
		1: return Color("#ffd166")
		_: return Color("#ff7eb6")

