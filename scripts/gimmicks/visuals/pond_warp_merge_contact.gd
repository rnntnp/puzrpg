extends RefCounted
## Additional visual merge contact; native collision merges remain unchanged.
const Constraints = preload("res://scripts/gimmicks/visuals/pond_warp_constraints.gd")
const SEARCH_SCALE := 1.28
const CELL_SIZE := 96.0

static func check(states: Array, max_level: int) -> void:
	var grid := {}
	var tested := {}
	var outlines := {}
	for index in states.size():
		var state: Dictionary = states[index]
		var ball: MergeBall = state.ball
		if not _eligible(ball, max_level): continue
		var center: Vector2 = state.to_board * state.circle_center
		var reach: float = ball.get_radius() * SEARCH_SCALE
		var first := Vector2i(((center - Vector2.ONE * reach) / CELL_SIZE).floor())
		var last := Vector2i(((center + Vector2.ONE * reach) / CELL_SIZE).floor())
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell): grid[cell] = []
				for other_index in grid[cell]:
					var key := Vector2i(other_index, index)
					if tested.has(key): continue
					tested[key] = true
					var other: Dictionary = states[other_index]
					if not _eligible(ball, max_level): break
					if not _eligible(other.ball, max_level) or ball.merge_level != other.ball.merge_level: continue
					var other_center: Vector2 = other.to_board * other.circle_center
					var limit: float = reach + other.ball.get_radius() * SEARCH_SCALE
					if center.distance_squared_to(other_center) > limit * limit: continue
					if not outlines.has(index): outlines[index] = _outline(state)
					if not outlines.has(other_index): outlines[other_index] = _outline(other)
					if _touches(outlines[index], outlines[other_index]):
						# Match native ball contact: landing must precede merge removal,
						# or a launched ball can vanish with the next drop still locked.
						ball.notify_custom_contact()
						other.ball.notify_custom_contact()
						ball.request_merge_with(other.ball)
				grid[cell].append(index)

static func _eligible(ball: MergeBall, max_level: int) -> bool:
	return is_instance_valid(ball) and not ball.is_queued_for_deletion() and not ball.merge_locked and not ball.is_ice_frozen and not ball.ice_cast_reserved and not ball.split_cast_reserved and ball.merge_level < max_level

static func _outline(state: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var center_weights := Constraints.bind(state.circle_center, state.rest)
	var center: Vector2 = state.circle_center + Constraints.offset(state, center_weights)
	var scale: float = state.get("merge_outline_scale", 1.1)
	for point: Vector2 in state.merge_outline:
		var weights := Constraints.bind(point, state.rest)
		var warped: Vector2 = point + Constraints.offset(state, weights)
		result.append(state.to_board * (center + (warped - center) * scale))
	return result

static func _touches(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3: return false
	if Geometry2D.is_point_in_polygon(a[0], b) or Geometry2D.is_point_in_polygon(b[0], a): return true
	for i in a.size():
		for j in b.size():
			if Geometry2D.segment_intersects_segment(a[i], a[(i + 1) % a.size()], b[j], b[(j + 1) % b.size()]) != null:
				return true
	return false
