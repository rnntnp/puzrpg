class_name SkillReadyOutlinePulse
extends ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if material != null:
		material = material.duplicate()


func set_skill_texture(skill_texture: Texture2D) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("skill_texture", skill_texture)


func set_active(active: bool) -> void:
	visible = active


func set_hovered(hovered: bool) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("hovered", hovered)
