extends RefCounted
## Runtime shader layers preserve the source atlas; no destructive image edit.
var body: Sprite2D
var features: Sprite2D
var original_material: Material

func configure(ball: MergeBall) -> void:
	if ball.visual_container.get_child_count() == 0: return
	var visual := ball.visual_container.get_child(0)
	body = visual.get_node_or_null("Axolotl") as Sprite2D
	if body == null or not body.texture is AtlasTexture or not body.material is ShaderMaterial: return
	original_material = body.material
	var source := body.material as ShaderMaterial
	var code := source.shader.code
	var fragment := code.find("void fragment()")
	if fragment < 0: return
	var opening := code.find("{", fragment)
	var depth := 1
	var end := opening + 1
	while depth > 0 and end < code.length():
		if code[end] == "{": depth += 1
		elif code[end] == "}": depth -= 1
		end += 1
	code = code.insert(end - 1, "\nCOLOR = pond_face_layer(COLOR, TEXTURE, UV, face_layer_modulate);\n")
	code = code.insert(opening + 1, "\nvec3 face_layer_modulate = face_layer_tint.rgb;\n")
	# Fragment COLOR already contains the sampled facial texture. Capture tint
	# in vertex() instead, or erased eyes/mouth get multiplied back into the skin.
	code = code.replace("shader_type canvas_item;", "shader_type canvas_item;\nvarying vec4 face_layer_tint;\n#include \"res://shaders/pond_face_layers.gdshaderinc\"\n")
	code += "\nvoid vertex() { face_layer_tint = COLOR; }\n"
	var shader := Shader.new()
	shader.code = code
	var body_material := source.duplicate() as ShaderMaterial
	body_material.shader = shader
	var atlas := body.texture as AtlasTexture
	var region := Vector4(atlas.region.position.x, atlas.region.position.y, atlas.region.size.x, atlas.region.size.y)
	body_material.set_shader_parameter("face_atlas_region", region)
	body_material.set_shader_parameter("face_layer_role", 1)
	var face_material := body_material.duplicate() as ShaderMaterial
	face_material.set_shader_parameter("face_layer_role", 2)
	features = body.duplicate() as Sprite2D
	features.name = "FaceFeatures"
	features.z_index = body.z_index + 1
	features.material = face_material
	visual.add_child(features)
	body.material = body_material

func restore() -> void:
	if is_instance_valid(body) and original_material != null: body.material = original_material
	if is_instance_valid(features): features.queue_free()
