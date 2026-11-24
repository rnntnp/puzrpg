extends "res://scripts/gimmicks/visuals/soft_pond_meshes.gd"
var detailed_interior_mesh := false

func update_surface(state: Dictionary, tuning: Resource) -> void:
	super.update_surface(state, tuning)
	var visual := ball.visual_container.get_child(0)
	var face := visual.get_node_or_null("FaceFeatures")
	var body := visual.get_node_or_null("Axolotl") as Sprite2D
	var center_fit: Dictionary = _center_fit(state) if state.get("interior_warp_gain", 1.0) > 1.0 else {"radius":1.0}
	for record: Dictionary in records:
		if not is_instance_valid(record.source): continue
		var is_face: bool = face != null and (record.source == face or face.is_ancestor_of(record.source))
		var is_head: bool = body != null and (record.source == body or body.is_ancestor_of(record.source))
		var gain: float = state.get("interior_warp_gain", 1.0) if is_face or is_head else 1.0
		record.material.set_shader_parameter("soft_interior_gain", gain)
		record.material.set_shader_parameter("soft_center_radius", center_fit.radius)
		var vertical_gain := Vector2(tuning.center_warp_upper_weight, tuning.center_warp_lower_weight) if is_face or is_head else Vector2.ONE
		record.material.set_shader_parameter("soft_vertical_gain", vertical_gain)
		var strain: float = state.get("face_strain_weight", 1.0) if is_face else 1.0
		record.material.set_shader_parameter("soft_strain_weight", strain)
		if is_face and body != null:
			record.mesh_node.modulate = body.modulate * body.self_modulate

func _sprite_grid_size(source: Sprite2D) -> int:
	return 20 if detailed_interior_mesh and (source.name == &"Axolotl" or source.name == &"FaceFeatures") else 10

func _center_fit(state: Dictionary) -> Dictionary:
	var center := Vector2.ZERO
	for i in state.rest.size():
		center += state.rest[i] / state.rest.size()
	var radius := INF
	for i in state.rest.size():
		var edge := Geometry2D.get_closest_point_to_segment(center, state.rest[i], state.rest[(i + 1) % state.rest.size()])
		radius = minf(radius, center.distance_to(edge))
	return {"radius":maxf(0.001, radius * 0.95)}

## Isolate shader parameters from shared materials and non-ball objects.
func _install_material(source: CanvasItem) -> Dictionary:
	var original := source.material
	if original != null:
		source.material = original.duplicate()
	var record := super._install_material(source)
	record.original_material = original
	return record
