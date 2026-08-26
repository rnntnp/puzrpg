class_name MirrorFaceSheen
extends Sprite2D

const SheenShader = preload("res://shaders/mirror_face_sheen.gdshader")

var sheen_texture: Texture2D


func configure(fighter: Fighter, active_texture: Texture2D) -> void:
	sheen_texture = active_texture
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SheenShader
	z_index = fighter.character_sprite.z_index + 1
	sync_from_fighter(fighter)
	set_sheen_active(false)


func set_sheen_active(active: bool) -> void:
	# Idle에서는 텍스처 자체를 분리해 중복 스프라이트가 렌더될 여지를 없앤다.
	texture = sheen_texture if active else null
	visible = active


func sync_from_fighter(fighter: Fighter) -> void:
	position = fighter.character_sprite.position
	scale = fighter.character_sprite.scale
	flip_h = fighter.character_sprite.flip_h
