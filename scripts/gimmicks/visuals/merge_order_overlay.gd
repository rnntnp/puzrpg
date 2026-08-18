class_name MergeOrderOverlay
extends Node2D

var board_bounds: Rect2 = Rect2()
var target_zone := 0
var target_result_stage := -1
var route_step := 1
var route_length := 1
var turns_remaining := 0
var result_text := ""
var has_last_merge := false
var last_merge_origin := Vector2.ZERO
var last_merge_matched := false


func show_state(
	bounds: Rect2,
	zone: int,
	result_stage: int,
	current_route_step: int,
	total_route_steps: int,
	turns: int,
	result: String,
	show_last_merge: bool,
	merge_origin: Vector2,
	merge_matched: bool
) -> void:
	board_bounds = bounds
	target_zone = clampi(zone, 0, 2)
	target_result_stage = result_stage
	route_step = maxi(1, current_route_step)
	route_length = maxi(1, total_route_steps)
	turns_remaining = maxi(0, turns)
	result_text = result
	has_last_merge = show_last_merge
	last_merge_origin = merge_origin
	last_merge_matched = merge_matched
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	var section_width: float = board_bounds.size.x / 3.0
	for zone_index in 3:
		var zone_rect := Rect2(
			Vector2(board_bounds.position.x + section_width * float(zone_index), board_bounds.position.y),
			Vector2(section_width, board_bounds.size.y)
		)
		if zone_index == target_zone:
			draw_rect(zone_rect, Color(0.16, 0.72, 1.0, 0.18), true)
			draw_rect(zone_rect.grow(-3.0), Color("#62d8ff"), false, 4.0)
		else:
			draw_rect(zone_rect, Color(0.02, 0.06, 0.12, 0.06), true)
		if zone_index > 0:
			var divider_x: float = zone_rect.position.x
			draw_line(
				Vector2(divider_x, board_bounds.position.y),
				Vector2(divider_x, board_bounds.end.y),
				Color(0.7, 0.9, 1.0, 0.45),
				2.0
			)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(zone_rect.position.x, board_bounds.end.y - 18.0),
			_zone_name(zone_index),
			HORIZONTAL_ALIGNMENT_CENTER,
			zone_rect.size.x,
			16,
			Color("#d7f5ff")
		)

	var stage_text: String = "ANY" if target_result_stage < 0 else "STAGE %d" % target_result_stage
	var route_text: String = "ORDER" if route_length <= 1 else "ROUTE %d/%d" % [route_step, route_length]
	var headline: String = "%s  %s  ·  %s  ·  %d TURN" % [
		route_text,
		_zone_name(target_zone),
		stage_text,
		turns_remaining,
	]
	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 32.0),
		headline,
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		20,
		Color("#ffd166")
	)
	if has_last_merge:
		var feedback_color: Color = Color("#70ff9b") if last_merge_matched else Color("#ff7b7b")
		draw_circle(last_merge_origin, 20.0, Color(feedback_color, 0.22))
		draw_arc(last_merge_origin, 24.0, 0.0, TAU, 32, feedback_color, 5.0, true)
	if not result_text.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, board_bounds.position.y + 60.0),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			18,
			Color.WHITE
		)


func _zone_name(zone: int) -> String:
	match clampi(zone, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"

