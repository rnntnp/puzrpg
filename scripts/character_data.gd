class_name CharacterData
extends Resource

@export_category("기본 정보")
@export var display_name: String = "Fighter"
@export var display_color: Color = Color.WHITE
@export var health_bar_color: Color = Color("#b838e0")

@export_category("캐릭터 표시")
@export var sprite: Texture2D
@export var cast_sprite: Texture2D
@export var ingestion_telegraph_sprite: Texture2D
@export var ingestion_swallowed_sprite: Texture2D
@export var ingestion_mouth_offset: Vector2 = Vector2(-55.0, 0.0)
@export var ingestion_belly_glow_offset: Vector2 = Vector2(-8.0, 38.0)
@export var sprite_modulate: Color = Color.WHITE
@export var sprite_size: Vector2 = Vector2(190.0, 190.0)

@export_category("전투 능력치")
@export_range(1, 99999, 1) var max_health: int = 100
@export_range(0, 9999, 1) var attack_power: int = 10
@export_range(1, 20, 1) var enemy_attack_drop_interval: int = 3

@export_category("몬스터 스킬")
@export var ingestion_skill: Resource
@export var ice_skill: Resource
