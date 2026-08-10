class_name MergeAutoplayBot
extends Node

@export_range(0.1, 2.0, 0.05) var think_interval := 0.45

var enabled := false
var elapsed := 0.0
var merge_game


func _ready() -> void:
	merge_game = get_parent()


func _process(delta: float) -> void:
	if not enabled or not merge_game.can_accept_autoplay_drop():
		return
	elapsed += delta
	if elapsed < think_interval:
		return
	elapsed = 0.0
	merge_game.autoplay_drop_at(_choose_drop_x())


func set_enabled(value: bool) -> void:
	enabled = value
	elapsed = 0.0


func _choose_drop_x() -> float:
	var active_balls: Array = merge_game.get_active_balls()
	var current_level: int = merge_game.get_current_ball_level()
	var matching_x := _find_accessible_match(active_balls, current_level)
	if matching_x >= 0.0:
		return matching_x
	return _find_lowest_stack_position(active_balls)


func _find_accessible_match(active_balls: Array, level: int) -> float:
	var best_ball = null
	for candidate in active_balls:
		if candidate.merge_locked or candidate.merge_level != level:
			continue
		if _has_blocker_above(candidate, active_balls):
			continue
		if best_ball == null or candidate.position.y > best_ball.position.y:
			best_ball = candidate
	return -1.0 if best_ball == null else best_ball.position.x


func _has_blocker_above(candidate, active_balls: Array) -> bool:
	for other in active_balls:
		if other == candidate or other.merge_locked:
			continue
		var horizontal_gap: float = absf(other.position.x - candidate.position.x)
		if other.position.y < candidate.position.y and horizontal_gap < other.get_radius() + candidate.get_radius():
			return true
	return false


func _find_lowest_stack_position(active_balls: Array) -> float:
	var bounds: Rect2 = merge_game.get_board_inner_bounds()
	var center_x := bounds.get_center().x
	var horizontal_margin := 30.0
	var start_x := bounds.position.x + horizontal_margin
	var end_x := bounds.end.x - horizontal_margin
	var best_x := center_x
	var lowest_surface := -INF
	var x := start_x
	while x <= end_x:
		var surface := bounds.end.y - 16.0
		for ball in active_balls:
			if ball.merge_locked:
				continue
			if absf(ball.position.x - x) < ball.get_radius() + 28.0:
				surface = minf(surface, ball.position.y - ball.get_radius())
		var center_bonus := -absf(x - center_x) * 0.02
		var score := surface + center_bonus
		if score > lowest_surface:
			lowest_surface = score
			best_x = x
		x += 50.0
	return best_x
