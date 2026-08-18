class_name GimmickOverlay
extends Node2D

var zone_rect := Rect2()
var zone_color := Color.TRANSPARENT
var zone_label := ""
var gravity_center := Vector2.ZERO
var gravity_radius := 0.0
var portal_entrance := Vector2.ZERO
var portal_exit := Vector2.ZERO
var portals_visible := false
var telegraph_rect := Rect2()
var echo_markers: Array[Vector2] = []
var mirror_visible := false
var mirror_center_x := 0.0
var mirror_ghost_x := 0.0
var mirror_drop_y := 0.0
var targeting_visible := false
var targeting_bounds := Rect2()
var targeting_section := 0
var stance_visible := false
var stance_bounds := Rect2()
var stance_side := 0
var stance_show_weak := false
var stance_show_attack := false
var filter_visible := false
var filter_bounds := Rect2()
var filter_y := 0.0
var filter_left_pass := 2
var filter_right_pass := 2
var filter_is_split := false
var filter_change_turns := -1


func clear_all() -> void:
	zone_rect = Rect2()
	zone_color = Color.TRANSPARENT
	zone_label = ""
	gravity_radius = 0.0
	portals_visible = false
	telegraph_rect = Rect2()
	echo_markers.clear()
	mirror_visible = false
	targeting_visible = false
	stance_visible = false
	filter_visible = false
	queue_redraw()


func show_zone(rect: Rect2, color: Color, label: String) -> void:
	zone_rect = rect
	zone_color = color
	zone_label = label
	queue_redraw()


func clear_zone() -> void:
	zone_rect = Rect2()
	zone_label = ""
	queue_redraw()


func show_gravity(center: Vector2, radius: float) -> void:
	gravity_center = center
	gravity_radius = radius
	queue_redraw()


func clear_gravity() -> void:
	gravity_radius = 0.0
	queue_redraw()


func show_portals(entrance: Vector2, exit: Vector2) -> void:
	portal_entrance = entrance
	portal_exit = exit
	portals_visible = true
	queue_redraw()


func clear_portals() -> void:
	portals_visible = false
	queue_redraw()


func show_telegraph(rect: Rect2) -> void:
	telegraph_rect = rect
	queue_redraw()


func clear_telegraph() -> void:
	telegraph_rect = Rect2()
	queue_redraw()


func show_echo_markers(markers: Array[Vector2]) -> void:
	echo_markers = markers.duplicate()
	queue_redraw()


func show_mirror(center_x: float, ghost_x: float, drop_y: float) -> void:
	mirror_visible = true
	mirror_center_x = center_x
	mirror_ghost_x = ghost_x
	mirror_drop_y = drop_y
	queue_redraw()


func clear_mirror() -> void:
	mirror_visible = false
	queue_redraw()


func show_board_targeting(bounds: Rect2, section: int) -> void:
	targeting_visible = true
	targeting_bounds = bounds
	targeting_section = clampi(section, 0, 2)
	queue_redraw()


func clear_board_targeting() -> void:
	targeting_visible = false
	queue_redraw()


func show_enemy_stance(bounds: Rect2, side: int, show_weak: bool, show_attack: bool) -> void:
	stance_visible = true
	stance_bounds = bounds
	stance_side = clampi(side, 0, 1)
	stance_show_weak = show_weak
	stance_show_attack = show_attack
	queue_redraw()


func clear_enemy_stance() -> void:
	stance_visible = false
	queue_redraw()


func show_stage_filter(
	bounds: Rect2,
	platform_y: float,
	left_pass: int,
	right_pass: int,
	is_split: bool,
	change_turns: int
) -> void:
	filter_visible = true
	filter_bounds = bounds
	filter_y = platform_y
	filter_left_pass = left_pass
	filter_right_pass = right_pass
	filter_is_split = is_split
	filter_change_turns = change_turns
	queue_redraw()


func clear_stage_filter() -> void:
	filter_visible = false
	queue_redraw()


func _draw() -> void:
	if zone_rect.has_area():
		draw_rect(zone_rect, zone_color, true)
		draw_rect(zone_rect, Color(zone_color, minf(1.0, zone_color.a + 0.5)), false, 5.0)
		if not zone_label.is_empty():
			draw_string(ThemeDB.fallback_font, zone_rect.position + Vector2(12.0, 34.0), zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color.WHITE)
	if gravity_radius > 0.0:
		draw_circle(gravity_center, gravity_radius, Color(0.48, 0.25, 0.92, 0.16))
		draw_arc(gravity_center, gravity_radius, 0.0, TAU, 56, Color(0.72, 0.48, 1.0, 0.9), 5.0, true)
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var outer := gravity_center + Vector2.from_angle(angle) * gravity_radius * 0.78
			var inner := gravity_center + Vector2.from_angle(angle) * gravity_radius * 0.45
			draw_line(outer, inner, Color(0.88, 0.72, 1.0, 0.8), 3.0, true)
	if portals_visible:
		_draw_portal(portal_entrance, Color("#63e6ff"), "IN")
		_draw_portal(portal_exit, Color("#ff8ef5"), "OUT")
		draw_dashed_line(portal_entrance, portal_exit, Color(0.8, 0.72, 1.0, 0.4), 3.0, 10.0)
	if telegraph_rect.has_area():
		draw_rect(telegraph_rect, Color(1.0, 0.25, 0.16, 0.16), true)
		draw_rect(telegraph_rect, Color(1.0, 0.55, 0.25, 0.95), false, 6.0)
		var center := telegraph_rect.get_center()
		draw_line(center + Vector2(-22, -22), center + Vector2(22, 22), Color.WHITE, 7.0, true)
		draw_line(center + Vector2(22, -22), center + Vector2(-22, 22), Color.WHITE, 7.0, true)
	for marker in echo_markers:
		draw_circle(marker, 34.0, Color(0.35, 0.9, 1.0, 0.13))
		draw_arc(marker, 34.0, 0.0, TAU, 36, Color("#7bdff2"), 4.0, true)
		draw_string(ThemeDB.fallback_font, marker + Vector2(-7.0, 7.0), "1", HORIZONTAL_ALIGNMENT_CENTER, 14.0, 18, Color.WHITE)
	if mirror_visible:
		draw_dashed_line(Vector2(mirror_center_x, 0.0), Vector2(mirror_center_x, 860.0), Color(0.75, 0.9, 1.0, 0.65), 3.0, 9.0)
		draw_circle(Vector2(mirror_ghost_x, mirror_drop_y), 18.0, Color(0.68, 0.88, 1.0, 0.22))
		draw_arc(Vector2(mirror_ghost_x, mirror_drop_y), 18.0, 0.0, TAU, 28, Color(0.8, 0.94, 1.0, 0.85), 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(mirror_center_x - 28.0, mirror_drop_y + 42.0), "MIRROR", HORIZONTAL_ALIGNMENT_CENTER, 56.0, 13, Color.WHITE)
	if targeting_visible:
		var section_width := targeting_bounds.size.x / 3.0
		for index in 3:
			var rect := Rect2(Vector2(targeting_bounds.position.x + section_width * index, targeting_bounds.position.y), Vector2(section_width, targeting_bounds.size.y))
			if index == targeting_section:
				draw_rect(rect, Color(1.0, 0.25, 0.2, 0.2), true)
				draw_rect(rect.grow(-3.0), Color("#ff6b6b"), false, 6.0)
			draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + 28.0), ["LEFT", "CENTER", "RIGHT"][index], HORIZONTAL_ALIGNMENT_CENTER, section_width, 17, Color.WHITE)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), Color(0.75, 0.86, 1.0, 0.5), 2.0, true)
		var target_rect := Rect2(Vector2(targeting_bounds.position.x + section_width * targeting_section, targeting_bounds.position.y), Vector2(section_width, targeting_bounds.size.y))
		draw_string(ThemeDB.fallback_font, Vector2(target_rect.position.x, target_rect.position.y + 58.0), "TARGET", HORIZONTAL_ALIGNMENT_CENTER, section_width, 20, Color("#ffd166"))
	if stance_visible:
		var half_width := stance_bounds.size.x * 0.5
		for index in 2:
			var rect := Rect2(Vector2(stance_bounds.position.x + half_width * index, stance_bounds.position.y), Vector2(half_width, stance_bounds.size.y))
			var is_stance := index == stance_side
			var is_weak := stance_show_weak and index != stance_side
			if is_weak:
				draw_rect(rect, Color(0.25, 1.0, 0.55, 0.13), true)
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 57.0), "WEAK", HORIZONTAL_ALIGNMENT_CENTER, half_width, 18, Color("#70ff9b"))
			if stance_show_attack and is_stance:
				draw_rect(rect, Color(1.0, 0.24, 0.2, 0.16), true)
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 82.0), "ATTACK", HORIZONTAL_ALIGNMENT_CENTER, half_width, 18, Color("#ff7b72"))
			if is_stance:
				draw_rect(rect.grow(-3.0), Color("#ffd166"), false, 6.0)
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 32.0), "STANCE", HORIZONTAL_ALIGNMENT_CENTER, half_width, 19, Color("#ffd166"))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 108.0), ["LEFT", "RIGHT"][index], HORIZONTAL_ALIGNMENT_CENTER, half_width, 17, Color.WHITE)
		var center_x := stance_bounds.get_center().x
		draw_line(Vector2(center_x, stance_bounds.position.y), Vector2(center_x, stance_bounds.end.y), Color(0.82, 0.9, 1.0, 0.8), 4.0, true)
	if filter_visible:
		var center_x := filter_bounds.get_center().x
		var left_rect := Rect2(Vector2(filter_bounds.position.x, filter_y - 5.0), Vector2(filter_bounds.size.x * (0.5 if filter_is_split else 1.0), 10.0))
		draw_rect(left_rect, Color(0.25, 0.85, 1.0, 0.28), true)
		draw_rect(left_rect, Color("#63e6ff"), false, 3.0)
		if filter_is_split:
			var right_rect := Rect2(Vector2(center_x, filter_y - 5.0), Vector2(filter_bounds.size.x * 0.5, 10.0))
			draw_rect(right_rect, Color(0.72, 0.48, 1.0, 0.28), true)
			draw_rect(right_rect, Color("#c77dff"), false, 3.0)
			draw_line(Vector2(center_x, filter_y - 24.0), Vector2(center_x, filter_y + 24.0), Color.WHITE, 3.0, true)
			draw_string(ThemeDB.fallback_font, Vector2(filter_bounds.position.x, filter_y - 15.0), "LEFT · PASS 1~%d" % filter_left_pass, HORIZONTAL_ALIGNMENT_CENTER, filter_bounds.size.x * 0.5, 18, Color("#9be8ff"))
			draw_string(ThemeDB.fallback_font, Vector2(center_x, filter_y - 15.0), "RIGHT · PASS 1~%d" % filter_right_pass, HORIZONTAL_ALIGNMENT_CENTER, filter_bounds.size.x * 0.5, 18, Color("#dfa8ff"))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(filter_bounds.position.x, filter_y - 15.0), "PASS 1~%d" % filter_left_pass, HORIZONTAL_ALIGNMENT_CENTER, filter_bounds.size.x, 20, Color("#9be8ff"))
		draw_string(ThemeDB.fallback_font, Vector2(filter_bounds.position.x + 8.0, filter_y - 47.0), "UPPER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 0.72))
		draw_string(ThemeDB.fallback_font, Vector2(filter_bounds.position.x + 8.0, filter_y + 31.0), "LOWER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 0.72))
		if filter_change_turns >= 0:
			draw_string(ThemeDB.fallback_font, Vector2(filter_bounds.position.x, filter_y + 57.0), "FILTER CHANGE · %d" % filter_change_turns, HORIZONTAL_ALIGNMENT_CENTER, filter_bounds.size.x, 18, Color("#ffd166"))


func _draw_portal(at: Vector2, color: Color, text: String) -> void:
	draw_circle(at, 42.0, Color(color, 0.18))
	draw_arc(at, 42.0, 0.0, TAU, 48, color, 7.0, true)
	draw_arc(at, 28.0, 0.0, TAU, 40, color.lightened(0.35), 3.0, true)
	draw_string(ThemeDB.fallback_font, at + Vector2(-20.0, 7.0), text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 15, Color.WHITE)
