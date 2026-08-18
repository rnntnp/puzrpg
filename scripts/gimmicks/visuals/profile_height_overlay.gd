class_name ProfileHeightOverlay
extends Node2D

var bounds := Rect2()
var profile_line_y := 0.0
var current_states: Array[int] = [0, 0, 0]
var target_profile := Vector3i(-1, -1, -1)
var turns_remaining := 0
var result_text := ""
var changed_sections: Array[int] = []


func show_state(
	board_bounds: Rect2,
	line_y: float,
	states: Array[int],
	target: Vector3i,
	turns: int,
	result: String,
	changed: Array[int]
) -> void:
	bounds = board_bounds
	profile_line_y = line_y
	current_states.assign(states)
	target_profile = target
	turns_remaining = turns
	result_text = result
	changed_sections.assign(changed)
	queue_redraw()


func _draw() -> void:
	var section_width: float = bounds.size.x / 3.0
	for index in 3:
		var section_rect := Rect2(
			Vector2(bounds.position.x + section_width * float(index), bounds.position.y),
			Vector2(section_width, bounds.size.y)
		)
		var is_high: bool = current_states[index] == 1
		var target_state: int = target_profile[index]
		var matches: bool = target_state < 0 or target_state == current_states[index]
		var state_color: Color = Color("#ffb86c") if is_high else Color("#63e6ff")
		var fill_rect: Rect2
		if is_high:
			fill_rect = Rect2(section_rect.position, Vector2(section_width, profile_line_y - bounds.position.y))
		else:
			fill_rect = Rect2(Vector2(section_rect.position.x, profile_line_y), Vector2(section_width, bounds.end.y - profile_line_y))
		draw_rect(fill_rect, Color(state_color, 0.08 if not is_high else 0.16), true)
		draw_line(section_rect.position, Vector2(section_rect.position.x, section_rect.end.y), Color(0.78, 0.88, 1.0, 0.38), 2.0, true)
		if index == 2:
			draw_line(Vector2(section_rect.end.x, section_rect.position.y), section_rect.end, Color(0.78, 0.88, 1.0, 0.38), 2.0, true)
		var label_y: float = profile_line_y + 32.0
		draw_string(ThemeDB.fallback_font, Vector2(section_rect.position.x, label_y), _section_name(index), HORIZONTAL_ALIGNMENT_CENTER, section_width, 16, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(section_rect.position.x, label_y + 25.0), _state_name(current_states[index]), HORIZONTAL_ALIGNMENT_CENTER, section_width, 20, state_color)
		var target_color: Color = Color("#70ff9b") if matches else Color("#ff6b6b")
		draw_string(
			ThemeDB.fallback_font,
			Vector2(section_rect.position.x, label_y + 50.0),
			"TARGET %s  %s" % [_state_name(target_state), "✓" if matches else "✕"],
			HORIZONTAL_ALIGNMENT_CENTER,
			section_width,
			15,
			target_color
		)
		if index in changed_sections:
			draw_rect(section_rect.grow(-4.0), state_color, false, 5.0)
	draw_dashed_line(
		Vector2(bounds.position.x, profile_line_y),
		Vector2(bounds.end.x, profile_line_y),
		Color("#f1fa8c"),
		4.0,
		12.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(bounds.position.x + 8.0, profile_line_y - 10.0),
		"PROFILE LINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color("#f1fa8c")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(bounds.position.x, bounds.position.y + 29.0),
		"TARGET PROFILE · %d턴" % turns_remaining,
		HORIZONTAL_ALIGNMENT_CENTER,
		bounds.size.x,
		19,
		Color("#ffd166")
	)
	if not result_text.is_empty():
		draw_rect(Rect2(Vector2(bounds.position.x + 76.0, bounds.get_center().y - 38.0), Vector2(bounds.size.x - 152.0, 76.0)), Color(0.04, 0.08, 0.16, 0.86), true)
		draw_string(ThemeDB.fallback_font, Vector2(bounds.position.x, bounds.get_center().y + 9.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 28, Color("#ffd166"))


func _state_name(state: int) -> String:
	if state < 0:
		return "ANY"
	return "HIGH" if state == 1 else "LOW"


func _section_name(index: int) -> String:
	match clampi(index, 0, 2):
		0: return "LEFT"
		1: return "CENTER"
		_: return "RIGHT"
