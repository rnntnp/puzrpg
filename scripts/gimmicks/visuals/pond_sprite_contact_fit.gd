extends RefCounted
## Alpha-outline contact anchors only; never alters native collision shapes.
var texture_contours: Dictionary = {}

func register(ball: MergeBall) -> PackedVector2Array:
	if ball.visual_container.get_child_count() == 0: return PackedVector2Array()
	var shell := ball.visual_container.get_child(0).get_node_or_null("ShellOutline") as Sprite2D
	if shell == null or shell.texture == null: return PackedVector2Array()
	var texture := shell.texture
	var id := texture.get_instance_id()
	if not texture_contours.has(id):
		var image := texture.get_image()
		if image == null: return PackedVector2Array()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image, 0.5)
		var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.0)
		var largest := PackedVector2Array()
		for polygon in polygons:
			if polygon.size() > largest.size(): largest = polygon
		texture_contours[id] = largest
	var rect := shell.get_rect()
	var size := texture.get_size()
	var expansion := Vector2.ONE
	if shell.material is ShaderMaterial:
		var texels: Variant = shell.material.get_shader_parameter("outline_expand_texels")
		if texels != null: expansion += Vector2.ONE / size * float(texels) * 2.0
	var to_body := ball.global_transform.affine_inverse() * shell.global_transform
	var result := PackedVector2Array()
	for pixel: Vector2 in texture_contours[id]:
		result.append(to_body * ((rect.position + pixel / size * rect.size) * expansion))
	return result

static func facing_point(state: Dictionary, direction: Vector2, fallback: Vector2) -> Vector2:
	var outline: PackedVector2Array = state.get("sprite_contact_outline", PackedVector2Array())
	if outline.size() < 3: return fallback
	var origin: Vector2 = state.to_board * state.circle_center
	var end: Vector2 = origin + direction * state.radius * 3.0
	var nearest := INF
	var result := fallback
	for i in outline.size():
		var a: Vector2 = state.to_board * outline[i]
		var b: Vector2 = state.to_board * outline[(i + 1) % outline.size()]
		var hit: Variant = Geometry2D.segment_intersects_segment(origin, end, a, b)
		if hit == null: continue
		var distance: float = origin.distance_squared_to(hit)
		if distance > 0.0001 and distance < nearest:
			nearest = distance
			result = hit
	return result
