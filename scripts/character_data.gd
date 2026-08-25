class_name CharacterData
extends Resource

@export_category("기본 정보")
@export var display_name: String = "Fighter":
	set(value):
		if display_name == value:
			return
		display_name = value
		emit_changed()
@export var display_color: Color = Color.WHITE:
	set(value):
		if display_color == value:
			return
		display_color = value
		emit_changed()
@export var health_bar_color: Color = Color("#b838e0"):
	set(value):
		if health_bar_color == value:
			return
		health_bar_color = value
		emit_changed()

@export_category("캐릭터 표시")
@export var sprite: Texture2D:
	set(value):
		if sprite == value:
			return
		sprite = value
		emit_changed()
@export var cast_sprite: Texture2D:
	set(value):
		if cast_sprite == value:
			return
		cast_sprite = value
		emit_changed()
@export var ingestion_telegraph_sprite: Texture2D
@export var ingestion_swallowed_sprite: Texture2D
@export var ingestion_mouth_offset: Vector2 = Vector2(-55.0, 0.0)
@export var ingestion_belly_glow_offset: Vector2 = Vector2(-8.0, 38.0)
@export var sprite_modulate: Color = Color.WHITE:
	set(value):
		if sprite_modulate == value:
			return
		sprite_modulate = value
		emit_changed()
@export var sprite_size: Vector2 = Vector2(190.0, 190.0):
	set(value):
		if sprite_size == value:
			return
		sprite_size = value
		emit_changed()
@export_range(-100.0, 100.0, 1.0) var sprite_horizontal_offset: float = 0.0:
	set(value):
		if is_equal_approx(sprite_horizontal_offset, value):
			return
		sprite_horizontal_offset = value
		emit_changed()
@export_range(-100.0, 100.0, 1.0) var sprite_height_offset: float = 0.0:
	set(value):
		if is_equal_approx(sprite_height_offset, value):
			return
		sprite_height_offset = value
		emit_changed()
@export_range(0.0, 12.0, 0.25) var outline_screen_size: float = 3.0:
	set(value):
		if is_equal_approx(outline_screen_size, value):
			return
		outline_screen_size = value
		emit_changed()
@export var shadow_scale: Vector2 = Vector2.ONE:
	set(value):
		if shadow_scale == value:
			return
		shadow_scale = value
		emit_changed()
@export var shadow_offset: Vector2 = Vector2(4.0, 119.0):
	set(value):
		if shadow_offset == value:
			return
		shadow_offset = value
		emit_changed()

@export_category("전투 능력치")
@export_range(1, 99999, 1) var max_health: int = 100:
	set(value):
		if max_health == value:
			return
		max_health = value
		emit_changed()
@export_range(0, 9999, 1) var attack_power: int = 10
@export_range(1, 20, 1) var enemy_attack_drop_interval: int = 3

@export_category("플레이어 스킬")
@export var player_skill: Resource

@export_category("몬스터 스킬")
@export var ingestion_skill: Resource
@export var ice_skill: Resource
