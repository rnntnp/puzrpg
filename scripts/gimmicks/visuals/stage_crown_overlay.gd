class_name StageCrownOverlay
extends Node2D

const MODE_UNIQUE_CROWN := 0
const MODE_TIED_CROWNS := 1
const MODE_STAIRCASE := 2
const DIRECTION_ASCENDING := 0
const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var enemy_mode := MODE_UNIQUE_CROWN
var crown_zone := 0
var crown_pair := Vector2i(0, 2)
var staircase_direction := DIRECTION_ASCENDING
var highest_stages: Array[int] = [0, 0, 0]
var ball_counts: Array[int] = [0, 0, 0]
var highest_positions: Array[Vector2] = []
var turns_remaining := 0
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	mode: int,
	target_zone: int,
	target_pair: Vector2i,
	direction: int,
	stages: Array[int],
	counts: Array[int],
	top_positions: Array[Vector2],
	turns: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	enemy_mode = mode
	crown_zone = target_zone
	crown_pair = target_pair
	staircase_direction = direction
	highest_stages.assign(stages)
	ball_counts.assign(counts)
	highest_positions.assign(top_positions)
	turns_remaining = maxi(0, turns)
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	var section_width: float = board_bounds.size.x / 3.0
	for zone in 3:
		var section_rect: Rect2 = Rect2(
			Vector2(board_bounds.position.x + section_width * float(zone), board_bounds.position.y),
			Vector2(section_width, board_bounds.size.y)
		)
		var is_target: bool = _zone_is_target(zone)
		var zone_tint: Color = Color(0.98, 0.78, 0.22, 0.10) if is_target else Color(0.08, 0.18, 0.28, 0.035)
		draw_rect(section_rect, zone_tint, true)
		if zone > 0:
			draw_line(Vector2(section_rect.position.x, section_rect.position.y), Vector2(section_rect.position.x, section_rect.end.y), Color(0.72, 0.9, 1.0, 0.42), 2.0)
		var card_rect: Rect2 = Rect2(Vector2(section_rect.position.x + 8.0, board_bounds.position.y + 48.0), Vector2(section_width - 16.0, 82.0))
		draw_rect(card_rect, Color(0.04, 0.09, 0.16, 0.86), true)
		draw_rect(card_rect, Color("#ffd166") if is_target else Color("#5f7d99"), false, 2.5)
		draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 24.0), _zone_name(zone), HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 15, Color("#d7f5ff"))
		var stage_text: String = "TOP —" if highest_stages[zone] <= 0 else "TOP S%d" % highest_stages[zone]
		draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 51.0), stage_text, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 21, Color("#70e7ff"))
		draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y + 72.0), "%d BALL" % ball_counts[zone], HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 13, Color("#aebfd0"))
		if is_target:
			draw_string(ThemeDB.fallback_font, Vector2(card_rect.position.x, card_rect.position.y - 8.0), "CROWN", HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 13, Color("#ffd166"))
	if enemy_mode == MODE_STAIRCASE:
		var relation_text: String = "S1 < S2 < S3" if staircase_direction == DIRECTION_ASCENDING else "S1 > S2 > S3"
		draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.position.y + 157.0), relation_text, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 19, Color("#ffd166"))
	for top_ball_position: Vector2 in highest_positions:
		draw_circle(top_ball_position, 25.0, Color(0.32, 0.9, 1.0, 0.10))
		draw_arc(top_ball_position, 27.0, 0.0, TAU, 28, Color("#70e7ff"), 4.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.position.y + 29.0), "STAGE CROWN · %d TURN" % turns_remaining, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 20, Color("#ffe69a"))
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect: Rect2 = Rect2(Vector2(board_bounds.position.x + 58.0, board_bounds.get_center().y - 38.0), Vector2(board_bounds.size.x - 116.0, 76.0))
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.9), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, board_bounds.size.x, 22, feedback_color)


func _zone_is_target(zone: int) -> bool:
	match enemy_mode:
		MODE_UNIQUE_CROWN:
			return zone == crown_zone
		MODE_TIED_CROWNS:
			return zone == crown_pair.x or zone == crown_pair.y
		MODE_STAIRCASE:
			return true
		_:
			return false


func _zone_name(zone: int) -> String:
	match clampi(zone, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"
