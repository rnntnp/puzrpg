class_name Fighter
extends Polygon2D

const CharacterDataClass = preload("res://scripts/character_data.gd")
const IceEyeGlowClass = preload("res://scripts/effects/ice_eye_glow.gd")

signal health_changed(current_health: int, max_health: int)
signal damage_received(amount: int)
signal defeated(fighter: Fighter)

@export var character_data: CharacterDataClass
@onready var character_sprite: Sprite2D = $Sprite2D
@onready var ingestion_belly_glow: IngestionBellyGlow = $IngestionBellyGlow

var current_health: int
var base_scale: Vector2
var _visual_tween: Tween
var _cast_tween: Tween
var _visual_override: Texture2D
var _ice_eye_glow: IceEyeGlow

var max_health: int:
	get: return character_data.max_health
var attack_power: int:
	get: return character_data.attack_power
var display_name: String:
	get: return character_data.display_name
var enemy_attack_drop_interval: int:
	get: return character_data.enemy_attack_drop_interval


func _ready() -> void:
	base_scale = scale
	assert(character_data != null, "%s에 CharacterData가 지정되지 않았습니다." % name)
	_ice_eye_glow = IceEyeGlowClass.new()
	add_child(_ice_eye_glow)
	if character_sprite.material != null:
		character_sprite.material = character_sprite.material.duplicate()
	_apply_character_visual()
	reset()


func set_character_data(data: CharacterDataClass, refill_health := true) -> void:
	_stop_cast_tween()
	character_data = data
	_visual_override = null
	_apply_character_visual()
	if refill_health:
		reset()


func _apply_character_visual() -> void:
	if character_data == null:
		return
	color = character_data.display_color
	character_sprite.modulate = character_data.display_color * character_data.sprite_modulate
	character_sprite.position = Vector2(
		character_data.sprite_horizontal_offset,
		character_data.sprite_height_offset
	)
	_apply_current_texture()
	# Polygon2D는 스프라이트가 없는 데이터의 예비 표시로만 사용한다.
	polygon = PackedVector2Array() if character_sprite.visible else PackedVector2Array([
		Vector2(-55, -75), Vector2(20, -75), Vector2(55, -35),
		Vector2(55, 70), Vector2(-55, 70)
	])


func set_visual_override(texture: Texture2D) -> void:
	_visual_override = texture
	_apply_current_texture()


func clear_visual_override() -> void:
	_visual_override = null
	_apply_current_texture()


func show_ingestion_glow(color: Color) -> void:
	ingestion_belly_glow.position = character_data.ingestion_belly_glow_offset
	ingestion_belly_glow.show_glow(color)


func hide_ingestion_glow() -> void:
	ingestion_belly_glow.hide_glow()


func show_ice_eye_glow() -> void:
	if _ice_eye_glow != null and character_data != null:
		_ice_eye_glow.show_glow(character_data.ice_eye_positions)


func hide_ice_eye_glow() -> void:
	if _ice_eye_glow != null:
		_ice_eye_glow.hide_glow()


func get_ingestion_mouth_global_position() -> Vector2:
	return to_global(character_data.ingestion_mouth_offset)


func get_spell_origin_global_position() -> Vector2:
	var toward_center := 1.0 if global_position.x < 360.0 else -1.0
	return global_position + Vector2(42.0 * toward_center, 5.0)


func _apply_current_texture() -> void:
	if character_data == null or character_sprite == null:
		return
	character_sprite.position = Vector2(
		character_data.sprite_horizontal_offset,
		character_data.sprite_height_offset
	)
	character_sprite.flip_h = character_data.sprite_flip_h
	character_sprite.texture = _visual_override if _visual_override != null else character_data.sprite
	character_sprite.visible = character_sprite.texture != null
	if character_sprite.texture == null:
		return
	var texture_size := character_sprite.texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		character_sprite.scale = Vector2(
			character_data.sprite_size.x / texture_size.x,
			character_data.sprite_size.y / texture_size.y
		)
		_apply_screen_space_outline()


func _apply_screen_space_outline() -> void:
	if not (character_sprite.material is ShaderMaterial):
		return
	var global_sprite_scale := character_sprite.get_global_transform_with_canvas().get_scale().abs()
	var average_scale := maxf((global_sprite_scale.x + global_sprite_scale.y) * 0.5, 0.001)
	var source_pixel_width := character_data.outline_screen_size / average_scale
	(character_sprite.material as ShaderMaterial).set_shader_parameter("outline_size", source_pixel_width)


func reset() -> void:
	current_health = max_health
	visible = true
	scale = base_scale
	modulate = Color.WHITE
	health_changed.emit(current_health, max_health)


func attack(target: Fighter) -> void:
	attack_with_damage(target, attack_power)

func attack_with_damage(target: Fighter, damage: int) -> void:
	if not is_alive() or not target.is_alive():
		return
	target.take_damage(damage)
	play_attack_animation(target)


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	var previous_health := current_health
	current_health = max(0, current_health - max(0, amount))
	var applied_damage := previous_health - current_health
	health_changed.emit(current_health, max_health)
	if applied_damage > 0:
		damage_received.emit(applied_damage)
	if current_health == 0:
		defeated.emit(self)
	else:
		play_hit_animation()


func heal(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0


func play_attack_animation(target: Fighter) -> void:
	_stop_visual_tween()
	var start_x := position.x
	var direction: float = signf(target.global_position.x - global_position.x)
	_visual_tween = create_tween()
	if character_data.attack_sprite != null:
		# 먼저 반대 방향으로 힘을 모은 뒤 공격 프레임으로 바꿔 타격 자세가
		# 한 프레임처럼 스쳐 지나가지 않게 한다.
		_visual_tween.tween_property(self, "position:x", start_x - 10.0 * direction, 0.10)
		_visual_tween.tween_callback(func():
			character_sprite.texture = character_data.attack_sprite
			var texture_size := character_data.attack_sprite.get_size()
			if texture_size.x > 0.0 and texture_size.y > 0.0:
				character_sprite.scale = Vector2(
					character_data.sprite_size.x / texture_size.x,
					character_data.sprite_size.y / texture_size.y
				)
				_apply_screen_space_outline()
		)
		_visual_tween.tween_property(self, "position:x", start_x + 45.0 * direction, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_visual_tween.tween_interval(0.20)
		_visual_tween.tween_property(self, "position:x", start_x, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_visual_tween.tween_property(self, "position:x", start_x + 45.0 * direction, 0.08)
		_visual_tween.tween_property(self, "position:x", start_x, 0.12)
	_visual_tween.tween_callback(func():
		_apply_current_texture()
	)


func play_hit_animation() -> void:
	_stop_visual_tween(not _is_cast_animation_active())
	var start_position := position
	var away_from_center := -1.0 if global_position.x < 360.0 else 1.0
	_visual_tween = create_tween()
	_visual_tween.set_parallel(true)
	_visual_tween.tween_property(self, "position", start_position + Vector2(18.0 * away_from_center, -3.0), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(self, "modulate", Color("#ffd0dc"), 0.055)
	_visual_tween.set_parallel(false)
	_visual_tween.tween_property(self, "position", start_position, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.13)


func play_cast_animation() -> void:
	if character_data == null or character_data.cast_sprite == null or not is_alive():
		return
	_stop_visual_tween()
	_stop_cast_tween()
	character_sprite.texture = character_data.cast_sprite
	character_sprite.position.y = character_data.sprite_height_offset + character_data.cast_sprite_height_offset
	var resting_scale := character_sprite.scale
	character_sprite.scale = resting_scale * 0.94
	_cast_tween = create_tween()
	_cast_tween.tween_property(character_sprite, "scale", resting_scale * 1.05, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_interval(0.32)
	_cast_tween.tween_property(character_sprite, "scale", resting_scale, 0.2)
	_cast_tween.tween_callback(func():
		_apply_current_texture()
		_cast_tween = null
	)


func play_ingestion_squash() -> void:
	if character_sprite == null or not is_alive():
		return
	_stop_visual_tween()
	var resting_scale := character_sprite.scale
	var squashed_scale := Vector2(resting_scale.x * 1.07, resting_scale.y * 0.80)
	_visual_tween = create_tween()
	_visual_tween.tween_property(character_sprite, "scale", squashed_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(character_sprite, "scale", resting_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_visual_tween(restore_texture := true) -> void:
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	modulate = Color.WHITE
	if restore_texture and character_data != null and character_sprite != null:
		_apply_current_texture()


func _is_cast_animation_active() -> bool:
	return _cast_tween != null and _cast_tween.is_valid() and _cast_tween.is_running()


func _stop_cast_tween() -> void:
	if _cast_tween != null and _cast_tween.is_valid():
		_cast_tween.kill()
	_cast_tween = null

func play_defeat_animation() -> void:
	var defeated_scale := Vector2(base_scale.x * 1.15, 0.05)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", defeated_scale, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color(1.0, 0.35, 0.35, 0.0), 0.65)
	await tween.finished
	visible = false
