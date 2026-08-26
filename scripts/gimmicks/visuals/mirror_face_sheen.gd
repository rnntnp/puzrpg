class_name MirrorFaceSheen
extends Sprite2D

const SheenShader = preload("res://shaders/mirror_face_sheen.gdshader")


func configure(fighter: Fighter, active_texture: Texture2D) -> void:
	texture = active_texture
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SheenShader
	z_index = fighter.character_sprite.z_index + 1
	visible = false
	sync_from_fighter(fighter)


func sync_from_fighter(fighter: Fighter) -> void:
	position = fighter.character_sprite.position
	scale = fighter.character_sprite.scale
	flip_h = fighter.character_sprite.flip_h
