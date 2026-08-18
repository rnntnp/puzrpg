class_name BoardStateTargetingOverlay
extends Node2D

var bounds := Rect2()
var section := 0


func show_target(board_bounds: Rect2, target_section: int) -> void:
	bounds = board_bounds
	section = clampi(target_section, 0, 2)
	queue_redraw()


func _draw() -> void:
	var section_width: float = bounds.size.x / 3.0
	for index in 3:
		var rect: Rect2 = Rect2(Vector2(bounds.position.x + section_width * index, bounds.position.y), Vector2(section_width, bounds.size.y))
		if index == section:
			draw_rect(rect, Color(1.0, 0.25, 0.2, 0.2), true)
			draw_rect(rect.grow(-3.0), Color("#ff6b6b"), false, 6.0)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + 28.0), ["LEFT", "CENTER", "RIGHT"][index], HORIZONTAL_ALIGNMENT_CENTER, section_width, 17, Color.WHITE)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), Color(0.75, 0.86, 1.0, 0.5), 2.0, true)
	var target_rect: Rect2 = Rect2(Vector2(bounds.position.x + section_width * section, bounds.position.y), Vector2(section_width, bounds.size.y))
	draw_string(ThemeDB.fallback_font, Vector2(target_rect.position.x, target_rect.position.y + 58.0), "TARGET", HORIZONTAL_ALIGNMENT_CENTER, section_width, 20, Color("#ffd166"))
