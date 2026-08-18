class_name SeesawWeightOverlay
extends Node2D

var bounds := Rect2()
var pivot := Vector2.ZERO
var seesaw_size := Vector2.ZERO
var seesaw_rotation := 0.0
var left_weight := 0.0
var right_weight := 0.0
var current_state := 0
var target_state := 2
var turns_remaining := -1
var result_text := ""
var state_emphasized := false


func show_state(
	board_bounds: Rect2,
	current_pivot: Vector2,
	current_size: Vector2,
	current_rotation: float,
	left_total: float,
	right_total: float,
	state: int,
	target: int,
	turns: int,
	result: String,
	emphasized: bool
) -> void:
	bounds = board_bounds
	pivot = current_pivot
	seesaw_size = current_size
	seesaw_rotation = current_rotation
	left_weight = left_total
	right_weight = right_total
	current_state = state
	target_state = target
	turns_remaining = turns
	result_text = result
	state_emphasized = emphasized
	queue_redraw()


func _draw() -> void:
	var half_size: Vector2 = seesaw_size * 0.5
	var corners: PackedVector2Array = PackedVector2Array([
		pivot + Vector2(-half_size.x, -half_size.y).rotated(seesaw_rotation),
		pivot + Vector2(half_size.x, -half_size.y).rotated(seesaw_rotation),
		pivot + Vector2(half_size.x, half_size.y).rotated(seesaw_rotation),
		pivot + Vector2(-half_size.x, half_size.y).rotated(seesaw_rotation),
	])
	var seesaw_color: Color = _state_color(current_state)
	draw_colored_polygon(corners, Color(seesaw_color, 0.55))
	var outline: PackedVector2Array = PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]])
	draw_polyline(outline, seesaw_color, 5.0, true)
	draw_colored_polygon(PackedVector2Array([
		pivot + Vector2(0.0, 3.0),
		pivot + Vector2(-24.0, 43.0),
		pivot + Vector2(24.0, 43.0),
	]), Color("#d9e2f2"))
	draw_circle(pivot, 9.0, Color("#ffd166"))
	draw_dashed_line(Vector2(bounds.get_center().x, bounds.position.y), Vector2(bounds.get_center().x, bounds.end.y), Color(0.75, 0.88, 1.0, 0.32), 2.0, 10.0)
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 28.0), "LEFT %.1f" % left_weight, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x * 0.5, 18, Color("#8be9fd"))
	draw_string(ThemeDB.fallback_font, Vector2(bounds.get_center().x, bounds.position.y + 28.0), "RIGHT %.1f" % right_weight, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x * 0.5, 18, Color("#ffb86c"))
	var state_size: int = 24 if state_emphasized else 20
	draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 58.0), "STATE: %s" % _state_name(current_state), HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, state_size, seesaw_color)
	if turns_remaining >= 0:
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.position.y + 87.0), "TARGET: %s · %d턴" % [_state_name(target_state), turns_remaining], HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 18, Color("#ffd166"))
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 76.0, bounds.get_center().y - 38.0), Vector2(bounds.size.x - 152.0, 76.0)), Color(0.04, 0.08, 0.16, 0.86), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 9.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 27, Color("#ffd166"))


func _state_name(state: int) -> String:
	if state < 0:
		return "LEFT HEAVY"
	if state > 0:
		return "RIGHT HEAVY"
	return "BALANCE"


func _state_color(state: int) -> Color:
	if state < 0:
		return Color("#63e6ff")
	if state > 0:
		return Color("#ff9f43")
	return Color("#70ff9b")
