@tool
class_name ParametricBallHitbox2D
extends StaticBody2D

@export var outline_texture: Texture2D:
	set(value):
		outline_texture = value
		_request_rebuild()
@export_range(0.01, 0.95, 0.01) var alpha_threshold := 0.2:
	set(value):
		alpha_threshold = value
		_request_rebuild()
@export_range(0.0, 1.0, 0.01) var hull_rounding := 0.0:
	set(value):
		hull_rounding = value
		_request_rebuild()
@export_range(2.0, 32.0, 1.0) var maximum_edge_length := 8.0:
	set(value):
		maximum_edge_length = value
		_request_rebuild()
@export_range(0.5, 1.2, 0.01) var hull_scale := 1.0:
	set(value):
		hull_scale = value
		_request_rebuild()
@export_range(1, 8, 1) var vertex_step := 1:
	set(value):
		vertex_step = value
		_request_rebuild()
@export var hull_axis_scale := Vector2.ONE:
	set(value):
		hull_axis_scale = Vector2(maxf(0.5, value.x), maxf(0.5, value.y))
		_request_rebuild()
@export var show_editor_preview := true:
	set(value):
		show_editor_preview = value
		queue_redraw()

static var _point_cache: Dictionary = {}

var _preview_points := PackedVector2Array()
var _rebuild_queued := false


func _ready() -> void:
	_rebuild_shape()


func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_shape.call_deferred()


func _rebuild_shape() -> void:
	_rebuild_queued = false
	var collision := get_node_or_null("HitboxBody") as CollisionShape2D
	if collision == null or outline_texture == null:
		return
	_preview_points = _get_outline_hull()
	if _preview_points.size() < 3:
		return
	var generated_shape := ConvexPolygonShape2D.new()
	generated_shape.points = _preview_points
	collision.position = Vector2.ZERO
	collision.rotation = 0.0
	collision.scale = Vector2.ONE
	collision.shape = generated_shape
	collision.disabled = false
	for child in get_children():
		if child is CollisionShape2D and child != collision:
			(child as CollisionShape2D).disabled = true
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_preview or _preview_points.size() < 3:
		return
	draw_colored_polygon(_preview_points, Color(0.2, 0.95, 1.0, 0.12))
	var outline := _preview_points.duplicate()
	outline.append(_preview_points[0])
	draw_polyline(outline, Color(0.25, 1.0, 1.0, 0.9), 3.0, true)


func _get_outline_hull() -> PackedVector2Array:
	var cache_key := "%s|%.2f|%.2f|%.1f|%.2f|%d|%.3f|%.3f" % [
		outline_texture.resource_path,
		alpha_threshold,
		hull_rounding,
		maximum_edge_length,
		hull_scale,
		vertex_step,
		hull_axis_scale.x,
		hull_axis_scale.y,
	]
	if _point_cache.has(cache_key):
		return (_point_cache[cache_key] as PackedVector2Array).duplicate()
	var image := outline_texture.get_image()
	if image == null or image.is_empty():
		return PackedVector2Array()
	var edge_points: Array[Vector2] = []
	var center := Vector2(image.get_width(), image.get_height()) * 0.5
	for y in image.get_height():
		var left := -1
		var right := -1
		for x in image.get_width():
			if image.get_pixel(x, y).a < alpha_threshold:
				continue
			if left < 0:
				left = x
			right = x
		if left >= 0:
			edge_points.append(Vector2(left, y) - center)
			if right != left:
				edge_points.append(Vector2(right, y) - center)
	var hull := _convex_hull(edge_points)
	if hull_rounding > 0.0:
		hull = _round_hull(hull)
	if not is_equal_approx(hull_scale, 1.0):
		for index in hull.size():
			hull[index] *= hull_scale
	if not hull_axis_scale.is_equal_approx(Vector2.ONE):
		for index in hull.size():
			hull[index] *= hull_axis_scale
	if vertex_step > 1:
		hull = _reduce_hull_vertices(hull, vertex_step)
	_point_cache[cache_key] = hull.duplicate()
	return hull


func _reduce_hull_vertices(hull: PackedVector2Array, step: int) -> PackedVector2Array:
	if step <= 1 or hull.size() <= 3:
		return hull
	var reduced := PackedVector2Array()
	for index in range(0, hull.size(), step):
		reduced.append(hull[index])
	return reduced if reduced.size() >= 3 else hull


func _round_hull(hull: PackedVector2Array) -> PackedVector2Array:
	if hull.size() < 3:
		return hull
	var minimum := hull[0]
	var maximum := hull[0]
	for point in hull:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var center := (minimum + maximum) * 0.5
	var radii := (maximum - minimum) * 0.5
	if radii.x <= 0.0 or radii.y <= 0.0:
		return hull
	var rounded_points: Array[Vector2] = []
	for index in hull.size():
		var start := hull[index]
		var finish := hull[(index + 1) % hull.size()]
		var segment_count := maxi(1, ceili(start.distance_to(finish) / maximum_edge_length))
		for segment in segment_count:
			var point := start.lerp(finish, float(segment) / float(segment_count))
			var direction := point - center
			if direction.is_zero_approx():
				continue
			var normalized_x := direction.x / radii.x
			var normalized_y := direction.y / radii.y
			var ellipse_distance := 1.0 / sqrt(
				normalized_x * normalized_x + normalized_y * normalized_y
			)
			var ellipse_point := center + direction * ellipse_distance
			rounded_points.append(point.lerp(ellipse_point, hull_rounding))
	return _convex_hull(rounded_points)


func _convex_hull(source: Array[Vector2]) -> PackedVector2Array:
	if source.size() < 3:
		return PackedVector2Array(source)
	var sorted := source.duplicate()
	sorted.sort_custom(_sort_point)
	var lower: Array[Vector2] = []
	for point in sorted:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], point) <= 0.0:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for index in range(sorted.size() - 1, -1, -1):
		var point: Vector2 = sorted[index]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], point) <= 0.0:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	var result := PackedVector2Array()
	for point in lower:
		result.append(point)
	for point in upper:
		result.append(point)
	return result


func _sort_point(first: Vector2, second: Vector2) -> bool:
	return first.x < second.x or (is_equal_approx(first.x, second.x) and first.y < second.y)


func _cross(origin: Vector2, first: Vector2, second: Vector2) -> float:
	return (first - origin).cross(second - origin)
