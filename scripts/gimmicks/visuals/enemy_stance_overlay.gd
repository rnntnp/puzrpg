class_name EnemyStanceOverlay
extends Node2D

var bounds := Rect2()
var stance_side := 0
var show_weak := false
var show_attack := false


func show_state(board_bounds: Rect2, side: int, weak: bool, attack: bool) -> void:
	bounds = board_bounds
	stance_side = clampi(side, 0, 1)
	show_weak = weak
	show_attack = attack
	queue_redraw()


func _draw() -> void:
	var half_width: float = bounds.size.x * 0.5
	for index in 2:
		var rect: Rect2 = Rect2(Vector2(bounds.position.x + half_width * index, bounds.position.y), Vector2(half_width, bounds.size.y))
		var is_stance: bool = index == stance_side
		if show_weak and not is_stance:
			draw_rect(rect, Color(0.25, 1.0, 0.55, 0.13), true)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 57.0), "WEAK", HORIZONTAL_ALIGNMENT_CENTER, half_width, 18, Color("#70ff9b"))
		if show_attack and is_stance:
			draw_rect(rect, Color(1.0, 0.24, 0.2, 0.16), true)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 82.0), "ATTACK", HORIZONTAL_ALIGNMENT_CENTER, half_width, 18, Color("#ff7b72"))
		if is_stance:
			draw_rect(rect.grow(-3.0), Color("#ffd166"), false, 6.0)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 32.0), "STANCE", HORIZONTAL_ALIGNMENT_CENTER, half_width, 19, Color("#ffd166"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 108.0), ["LEFT", "RIGHT"][index], HORIZONTAL_ALIGNMENT_CENTER, half_width, 17, Color.WHITE)
	var center_x: float = bounds.get_center().x
	draw_line(Vector2(center_x, bounds.position.y), Vector2(center_x, bounds.end.y), Color(0.82, 0.9, 1.0, 0.8), 4.0, true)
