class_name MergeDrivenTerrainOverlay
extends Node2D

var bounds := Rect2()
var shelf_position := Vector2.ZERO
var shelf_size := Vector2.ZERO
var divider_position := Vector2.ZERO
var divider_size := Vector2.ZERO
var shelf_visible := false
var divider_visible := false
var active_mode := 0
var mode_turns := -1
var left_merges := 0
var right_merges := 0
var movement_direction := 0


func show_state(
	board_bounds: Rect2,
	current_shelf_position: Vector2,
	current_shelf_size: Vector2,
	current_divider_position: Vector2,
	current_divider_size: Vector2,
	show_shelf: bool,
	show_divider: bool,
	mode: int,
	turns: int,
	left_count: int,
	right_count: int,
	direction: int
) -> void:
	bounds = board_bounds
	shelf_position = current_shelf_position
	shelf_size = current_shelf_size
	divider_position = current_divider_position
	divider_size = current_divider_size
	shelf_visible = show_shelf
	divider_visible = show_divider
	active_mode = mode
	mode_turns = turns
	left_merges = left_count
	right_merges = right_count
	movement_direction = direction
	queue_redraw()


func _draw() -> void:
	var center_x: float = bounds.get_center().x
	draw_dashed_line(
		Vector2(center_x, bounds.position.y),
		Vector2(center_x, bounds.end.y),
		Color(0.75, 0.88, 1.0, 0.38),
		2.0,
		10.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(bounds.position.x, bounds.position.y + 27.0),
		"LEFT 합성 %d" % left_merges,
		HORIZONTAL_ALIGNMENT_CENTER,
		bounds.size.x * 0.5,
		17,
		Color("#8be9fd")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x, bounds.position.y + 27.0),
		"RIGHT 합성 %d" % right_merges,
		HORIZONTAL_ALIGNMENT_CENTER,
		bounds.size.x * 0.5,
		17,
		Color("#ffb86c")
	)
	if shelf_visible:
		var shelf_rect: Rect2 = Rect2(shelf_position - shelf_size * 0.5, shelf_size)
		var shelf_color: Color = Color("#63e6ff") if active_mode == 0 else Color(0.39, 0.9, 1.0, 0.36)
		draw_rect(shelf_rect, Color(shelf_color, 0.28), true)
		draw_rect(shelf_rect, shelf_color, false, 4.0)
		draw_string(ThemeDB.fallback_font, shelf_rect.position + Vector2(0.0, -9.0), "SHELF", HORIZONTAL_ALIGNMENT_CENTER, shelf_rect.size.x, 16, shelf_color)
	if divider_visible:
		var divider_rect: Rect2 = Rect2(divider_position - divider_size * 0.5, divider_size)
		var divider_color: Color = Color("#c77dff") if active_mode == 1 else Color(0.78, 0.49, 1.0, 0.36)
		draw_rect(divider_rect, Color(divider_color, 0.24), true)
		draw_rect(divider_rect, divider_color, false, 4.0)
		draw_string(ThemeDB.fallback_font, divider_rect.position + Vector2(-42.0, -8.0), "DIVIDER", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 15, divider_color)
	if movement_direction != 0:
		var active_position: Vector2 = shelf_position if active_mode == 0 else divider_position
		var arrow_start: Vector2 = active_position + Vector2(-34.0 * movement_direction, -48.0)
		var arrow_end: Vector2 = active_position + Vector2(34.0 * movement_direction, -48.0)
		draw_line(arrow_start, arrow_end, Color("#ffd166"), 5.0, true)
		draw_colored_polygon(PackedVector2Array([
			arrow_end,
			arrow_end + Vector2(-13.0 * movement_direction, -9.0),
			arrow_end + Vector2(-13.0 * movement_direction, 9.0),
		]), Color("#ffd166"))
	if mode_turns >= 0:
		var mode_name: String = "SHELF MODE" if active_mode == 0 else "DIVIDER MODE"
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 53.0), "%s · %d턴" % [mode_name, mode_turns], HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 19, Color("#ffd166"))
