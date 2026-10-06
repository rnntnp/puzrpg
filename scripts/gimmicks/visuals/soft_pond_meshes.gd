extends RefCounted

const DeformationCode := preload("res://shaders/soft_pond_deformation.gdshaderinc")
static var shader_cache: Dictionary = {}
static var mesh_cache: Dictionary = {}
var ball: MergeBall
var records: Array = []
var installed: Dictionary = {}
var last_child_count := -1

func configure(target: MergeBall) -> void:
	ball = target

func install_pending() -> bool:
	var visual := ball.visual_container.get_child(0)
	if visual.get_child_count() == last_child_count:
		return false
	_scan(ball.visual_container)
	last_child_count = visual.get_child_count()
	return true

func update_surface(state: Dictionary, _tuning: Resource) -> void:
	install_pending()
	for record in records:
		if not is_instance_valid(record.source):
			continue
		var source: Node2D = record.source
		var mesh_node: MeshInstance2D = record.mesh_node
		if record.proxy:
			mesh_node.transform = source.transform
			mesh_node.modulate = source.modulate * source.self_modulate
			mesh_node.visible = record.visible
		var to_body := ball.global_transform.affine_inverse() * mesh_node.global_transform
		var inverse := to_body.affine_inverse()
		var material: ShaderMaterial = record.material
		material.set_shader_parameter("soft_basis", Vector4(to_body.x.x, to_body.x.y, to_body.y.x, to_body.y.y))
		material.set_shader_parameter("soft_inverse", Vector4(inverse.x.x, inverse.x.y, inverse.y.x, inverse.y.y))
		material.set_shader_parameter("soft_origin", to_body.origin)
		var deformation: Transform2D = state.applied
		material.set_shader_parameter("soft_deformation", Vector4(deformation.x.x, deformation.x.y, deformation.y.x, deformation.y.y))
		material.set_shader_parameter("soft_offset", deformation.origin)
		if state.has("surface_points"):
			var offsets := PackedVector2Array()
			for i in state.rest.size(): offsets.append(state.surface_points[i] - state.rest[i])
			material.set_shader_parameter("soft_point_count", state.rest.size())
			var rest_points: PackedVector2Array = state.rest.duplicate()
			rest_points.resize(16)
			offsets.resize(16)
			material.set_shader_parameter("soft_rest_points", rest_points)
			material.set_shader_parameter("soft_point_offsets", offsets)

func _scan(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta(&"soft_mesh_proxy"):
			continue
		# The reflection layer owns shader highlights. Never resurrect its hidden
		# authored gloss as a visible deformation proxy before it installs.
		if child.name == &"ShellGloss":
			continue
		if not installed.has(child.get_instance_id()) and child is Sprite2D and child.texture != null and child.visible:
			_install_sprite(child)
		elif not installed.has(child.get_instance_id()) and child is MeshInstance2D and child.mesh != null:
			_install_mesh(child)
		if child is Node2D and not child is CollisionObject2D:
			_scan(child)

func _install_material(source: CanvasItem) -> Dictionary:
	var original := source.material
	var material := original as ShaderMaterial
	var original_shader: Shader = material.shader if material != null else null
	if material == null:
		material = ShaderMaterial.new()
		source.material = material
	var code := original_shader.code if original_shader != null else "shader_type canvas_item;\nrender_mode unshaded;\n"
	if not shader_cache.has(code):
		var vertex_start := code.find("void vertex()")
		if vertex_start >= 0:
			var opening := code.find("{", vertex_start)
			var depth := 1
			var cursor := opening + 1
			while depth > 0 and cursor < code.length():
				if code[cursor] == "{": depth += 1
				if code[cursor] == "}": depth -= 1
				cursor += 1
			code = code.insert(cursor - 1, "\n VERTEX = soft_surface_vertex(VERTEX);\n")
		else:
			code += "\nvoid vertex() { VERTEX = soft_surface_vertex(VERTEX); }\n"
		code = code.replace("shader_type canvas_item;", "shader_type canvas_item;\n" + DeformationCode.code)
		var shader := Shader.new()
		shader.code = code
		# Cache by original code, not the generated variant.
		shader_cache[original_shader.code if original_shader != null else "shader_type canvas_item;\nrender_mode unshaded;\n"] = shader
	material.shader = shader_cache[original_shader.code if original_shader != null else "shader_type canvas_item;\nrender_mode unshaded;\n"]
	return {"material": material, "original_material": original, "original_shader": original_shader}

func _install_sprite(source: Sprite2D) -> void:
	var key := str(source.get_rect())
	if not mesh_cache.has(key):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		var rect := source.get_rect()
		const GRID := 10
		for y in GRID + 1:
			for x in GRID + 1:
				var coordinate := Vector2(x, y) / GRID
				vertices.append(rect.position + rect.size * coordinate)
				uv.append(coordinate)
		for y in GRID:
			for x in GRID:
				var a := y * (GRID + 1) + x
				indices.append_array(PackedInt32Array([a, a + 1, a + GRID + 1, a + 1, a + GRID + 2, a + GRID + 1]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_cache[key] = mesh
	var proxy := MeshInstance2D.new()
	proxy.name = "SoftSurface"
	proxy.set_meta(&"soft_mesh_proxy", true)
	proxy.mesh = mesh_cache[key]
	proxy.texture = source.texture
	proxy.texture_filter = source.texture_filter
	proxy.z_index = source.z_index
	var record := _install_material(source)
	proxy.material = record.material
	source.get_parent().add_child(proxy)
	installed[source.get_instance_id()] = true
	record.merge({"source": source, "mesh_node": proxy, "proxy": true, "visible": source.visible})
	records.append(record)
	source.hide()

func _install_mesh(source: MeshInstance2D) -> void:
	var record := _install_material(source)
	installed[source.get_instance_id()] = true
	record.merge({"source": source, "mesh_node": source, "proxy": false})
	records.append(record)

func restore() -> void:
	for record in records:
		if not is_instance_valid(record.source):
			continue
		record.material.shader = record.original_shader
		record.source.material = record.original_material
		if record.proxy:
			record.source.visible = record.visible
			record.mesh_node.queue_free()
	records.clear()
	installed.clear()
	last_child_count = -1
