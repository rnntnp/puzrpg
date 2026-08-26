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
	var cache_key := "%s|%.2f" % [outline_texture.resource_path, alpha_threshold]
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
	_point_cache[cache_key] = hull.duplicate()
	return hull


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
