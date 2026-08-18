class_name StageFilterBoardOverlay
extends Node2D

var bounds := Rect2()
var platform_y := 0.0
var left_pass := 2
var right_pass := 2
var is_split := false
var change_turns := -1


func show_filter(board_bounds: Rect2, y: float, left: int, right: int, split: bool, turns: int) -> void:
	bounds = board_bounds
	platform_y = y
	left_pass = left
	right_pass = right
	is_split = split
	change_turns = turns
	queue_redraw()


func _draw() -> void:
	var center_x: float = bounds.get_center().x
	var left_rect: Rect2 = Rect2(Vector2(bounds.position.x, platform_y - 5.0), Vector2(bounds.size.x * (0.5 if is_split else 1.0), 10.0))
	draw_rect(left_rect, Color(0.25, 0.85, 1.0, 0.28), true)
	draw_rect(left_rect, Color("#63e6ff"), false, 3.0)
	if is_split:
		var right_rect: Rect2 = Rect2(Vector2(center_x, platform_y - 5.0), Vector2(bounds.size.x * 0.5, 10.0))
		draw_rect(right_rect, Color(0.72, 0.48, 1.0, 0.28), true)
		draw_rect(right_rect, Color("#c77dff"), false, 3.0)
		draw_line(Vector2(center_x, platform_y - 24.0), Vector2(center_x, platform_y + 24.0), Color.WHITE, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, platform_y - 15.0), "LEFT · PASS 1~%d" % left_pass, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x * 0.5, 18, Color("#9be8ff"))
		draw_string(ThemeDB.fallback_font, Vector2(center_x, platform_y - 15.0), "RIGHT · PASS 1~%d" % right_pass, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x * 0.5, 18, Color("#dfa8ff"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, platform_y - 15.0), "PASS 1~%d" % left_pass, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 20, Color("#9be8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x + 8.0, platform_y - 47.0), "UPPER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 0.72))
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x + 8.0, platform_y + 31.0), "LOWER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 0.72))
	if change_turns >= 0:
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, platform_y + 57.0), "FILTER CHANGE · %d" % change_turns, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 18, Color("#ffd166"))
