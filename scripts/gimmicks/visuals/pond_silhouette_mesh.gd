extends RefCounted

# Meshes are shared between balls with the same actual silhouette texture.
static var cache: Dictionary = {}
static var fields: Dictionary = {}
const GRID := 65


static func build(texture: Texture2D, depth_ratio: float, smoothing_passes := 0) -> ArrayMesh:
	var key := "%s:%s:%s" % [texture.get_rid().get_id(), depth_ratio, smoothing_passes]
	if cache.has(key):
		return cache[key]
	var image := texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.2)
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.5)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var size := Vector2(image.get_size())
	var depth := minf(size.x, size.y) * depth_ratio
	for polygon in polygons:
		var field := _smooth_field(polygon, size)
		for pass_index in range(smoothing_passes):
			field = _filter_height(field)
		fields[key] = {"field": field, "size": size, "depth": depth}
		var indices := Geometry2D.triangulate_polygon(polygon)
		var points := PackedVector2Array()
		for i in range(0, indices.size(), 3):
			_subdivide(polygon[indices[i]], polygon[indices[i + 1]], polygon[indices[i + 2]], 2, points)
		for point in points:
			var z := _sample_height(point, field, size, depth)
			var normal := _surface_normal(point, field, size, depth)
			vertices.append(Vector3(point.x - size.x * 0.5, point.y - size.y * 0.5, z))
			normals.append(normal)
			# CanvasItem has no vertex NORMAL input: transfer the same mesh normal
			# through vertex color, then decode it in the vertex shader.
			colors.append(Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0))
			uvs.append(point / size)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cache[key] = mesh
	return mesh


static func _subdivide(a: Vector2, b: Vector2, c: Vector2, remaining: int, points: PackedVector2Array) -> void:
	if remaining == 0:
		points.append_array(PackedVector2Array([a, b, c]))
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_subdivide(a, ab, ca, remaining - 1, points)
	_subdivide(ab, b, bc, remaining - 1, points)
	_subdivide(ca, bc, c, remaining - 1, points)
	_subdivide(ab, bc, ca, remaining - 1, points)


static func _smooth_field(polygon: PackedVector2Array, size: Vector2) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(GRID * GRID)
	var inside := PackedByteArray()
	inside.resize(GRID * GRID)
	for y in range(1, GRID - 1):
		for x in range(1, GRID - 1):
			inside[y * GRID + x] = int(Geometry2D.is_point_in_polygon(Vector2(x, y) * size / float(GRID - 1), polygon))
	# Poisson surface: laplacian(u)=-1, with zero height outside the silhouette.
	# Unlike nearest-edge distance, this has no medial-axis ridges.
	for iteration in range(256):
		for y in range(1, GRID - 1):
			for x in range(1, GRID - 1):
				var i := y * GRID + x
				if inside[i] == 0:
					continue
				var target := (field[i - 1] + field[i + 1] + field[i - GRID] + field[i + GRID] + 1.0) * 0.25
				field[i] = maxf(0.0, lerpf(field[i], target, 1.7))
	var maximum := 0.001
	for value in field:
		maximum = maxf(maximum, value)
	for i in field.size():
		field[i] = sqrt(maxf(0.0, field[i] / maximum))
	return field


static func _filter_height(field: PackedFloat32Array) -> PackedFloat32Array:
	var result := field.duplicate()
	for y in range(1, GRID - 1):
		for x in range(1, GRID - 1):
			var sum := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var weight := (2.0 if dx == 0 else 1.0) * (2.0 if dy == 0 else 1.0)
					sum += field[(y + dy) * GRID + x + dx] * weight
			result[y * GRID + x] = sum / 16.0
	return result


static func _sample_height(point: Vector2, field: PackedFloat32Array, size: Vector2, depth: float) -> float:
	var p := (point / size * float(GRID - 1)).clamp(Vector2.ZERO, Vector2.ONE * (GRID - 1.001))
	var x := int(p.x)
	var y := int(p.y)
	var fx := p.x - x
	var fy := p.y - y
	return depth * lerpf(lerpf(field[y * GRID + x], field[y * GRID + x + 1], fx), lerpf(field[(y + 1) * GRID + x], field[(y + 1) * GRID + x + 1], fx), fy)


static func _surface_normal(point: Vector2, field: PackedFloat32Array, size: Vector2, depth: float) -> Vector3:
	var epsilon := minf(size.x, size.y) / float(GRID - 1)
	var dx := (_sample_height(point + Vector2(epsilon, 0.0), field, size, depth) - _sample_height(point - Vector2(epsilon, 0.0), field, size, depth)) / (2.0 * epsilon)
	var dy := (_sample_height(point + Vector2(0.0, epsilon), field, size, depth) - _sample_height(point - Vector2(0.0, epsilon), field, size, depth)) / (2.0 * epsilon)
	return Vector3(-dx, -dy, 1.0).normalized()


static func normal_texture(texture: Texture2D, depth_ratio: float, smoothing_passes := 0) -> ImageTexture:
	var key := "%s:%s:%s" % [texture.get_rid().get_id(), depth_ratio, smoothing_passes]
	if not fields.has(key):
		build(texture, depth_ratio, smoothing_passes)
	var record: Dictionary = fields[key]
	var resolution := 256 if smoothing_passes > 0 else 128
	var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBAH if smoothing_passes > 0 else Image.FORMAT_RGB8)
	for y in resolution:
		for x in resolution:
			var point: Vector2 = (Vector2(x, y) + Vector2.ONE * 0.5) / float(resolution) * record.size
			var normal := _surface_normal(point, record.field, record.size, record.depth)
			image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(image)
