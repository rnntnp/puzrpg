extends RefCounted
const FaceLayers = preload("res://scripts/gimmicks/visuals/pond_face_layers.gd")

static func split(ball: MergeBall) -> RefCounted:
	var layers := FaceLayers.new()
	layers.configure(ball)
	return layers

static func update(state: Dictionary, tuning: Resource) -> void:
	for record: Dictionary in state.visuals.records:
		if not is_instance_valid(record.source): continue
		var is_face: bool = record.source.name == &"FaceFeatures"
		record.material.set_shader_parameter("soft_interior_gain", 1.0)
		record.material.set_shader_parameter("soft_strain_weight", tuning.face_strain_weight if is_face else 1.0)

static func restore(states: Array) -> void:
	for state: Dictionary in states:
		if state.has("face_layers") and state.face_layers != null: state.face_layers.restore()
