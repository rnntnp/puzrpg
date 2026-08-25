@tool
extends Control

const LevelDataClass = preload("res://scripts/level_data.gd")
const CharacterDataClass = preload("res://scripts/character_data.gd")
const ENEMY_ATTACK_STATUS = preload("res://resources/effects/enemy_attack_countdown.tres")

const SOURCE_WIDTH := 941.0
const BOTTOM_SOURCE_HEIGHT := 322.0
const REFERENCE_VIEWPORT_WIDTH := 720.0
const TOP_REFERENCE_HEIGHT := 508.0

@export_category("프리뷰 대상")
@export var stage: LevelDataClass:
	set(value):
		_disconnect_resource(stage)
		stage = value
		_connect_resource(stage)
		_queue_refresh()
@export var monster: CharacterDataClass:
	set(value):
		_disconnect_resource(monster)
		monster = value
		_connect_resource(monster)
		_queue_refresh()

@export_category("배치")
@export var monster_position := Vector2(529.0, 300.0):
	set(value):
		monster_position = value
		_queue_refresh()
@export_range(0.1, 4.0, 0.05) var monster_display_scale := 1.5:
	set(value):
		monster_display_scale = value
		_queue_refresh()
@export var shadow_offset_from_monster := Vector2(4.0, 119.0):
	set(value):
		shadow_offset_from_monster = value
		_queue_refresh()

@onready var background_artwork: TextureRect = $BackgroundArtwork
@onready var layered_background: Control = $LayeredBackground
@onready var top_layer: TextureRect = $LayeredBackground/Top
@onready var middle_layer: TextureRect = $LayeredBackground/Middle
@onready var bottom_layer: TextureRect = $LayeredBackground/Bottom
@onready var monster_origin: Node2D = $MonsterOrigin
@onready var monster_sprite: Sprite2D = $MonsterOrigin/Sprite2D
@onready var monster_shadow: Polygon2D = $MonsterShadow
@onready var preview_ui: Control = $PreviewUI
@onready var stage_title: Label = $PreviewUI/StageTitle
@onready var enemy_progress: Label = $PreviewUI/EnemyProgress
@onready var player_name: Label = $PreviewUI/PlayerName
@onready var monster_name: Label = $PreviewUI/MonsterName
@onready var player_health_bar: Control = $PreviewUI/PlayerHealthBar
@onready var monster_health_bar: Control = $PreviewUI/MonsterHealthBar
@onready var player_status_row: Control = $PreviewUI/PlayerStatusEffects
@onready var player_status_icon: TextureRect = $PreviewUI/PlayerStatusEffects/Icon
@onready var monster_status_icon: TextureRect = $PreviewUI/MonsterStatusEffects/Icon


func _ready() -> void:
	if monster_sprite.material != null:
		monster_sprite.material = monster_sprite.material.duplicate()
	_connect_resource(stage)
	_connect_resource(monster)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_refresh_background_layout()


func _queue_refresh() -> void:
	if is_node_ready():
		_refresh.call_deferred()


func _connect_resource(resource: Resource) -> void:
	if resource != null and not resource.changed.is_connected(_queue_refresh):
		resource.changed.connect(_queue_refresh)


func _disconnect_resource(resource: Resource) -> void:
	if resource != null and resource.changed.is_connected(_queue_refresh):
		resource.changed.disconnect(_queue_refresh)


func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_background()
	_refresh_monster()
	_refresh_ui()


func _refresh_ui() -> void:
	preview_ui.visible = stage != null or monster != null
	stage_title.text = stage.level_name if stage != null else "스테이지 미지정"
	var player_data = stage.player_character if stage != null else null
	player_name.text = player_data.display_name if player_data != null else "플레이어"
	monster_name.text = monster.display_name if monster != null else "몬스터"
	var player_health: int = player_data.max_health if player_data != null else 100
	var monster_health: int = monster.max_health if monster != null else 100
	player_health_bar.call("set_health", player_health, player_health)
	monster_health_bar.call("set_health", monster_health, monster_health)
	if monster != null:
		monster_health_bar.set("fill_color", monster.health_bar_color)
	var enemy_count := stage.enemies.size() if stage != null else 0
	var enemy_index := stage.enemies.find(monster) if stage != null and monster != null else -1
	if enemy_count > 0:
		enemy_progress.text = "적 %d/%d" % [enemy_index + 1 if enemy_index >= 0 else 1, enemy_count]
	else:
		enemy_progress.text = "적 -/-"
	player_status_icon.texture = stage.stage_gimmick_icon if stage != null else null
	player_status_row.visible = player_status_icon.texture != null
	monster_status_icon.texture = ENEMY_ATTACK_STATUS.icon


func _refresh_background() -> void:
	var has_layers := (
		stage != null
		and stage.battle_background_top != null
		and stage.battle_background_middle != null
		and stage.battle_background_bottom != null
	)
	layered_background.visible = has_layers
	background_artwork.visible = not has_layers
	if stage == null:
		background_artwork.texture = null
		return
	background_artwork.texture = stage.battle_background
	if has_layers:
		top_layer.texture = stage.battle_background_top
		middle_layer.texture = stage.battle_background_middle
		bottom_layer.texture = stage.battle_background_bottom
		_refresh_background_layout()


func _refresh_background_layout() -> void:
	if not is_node_ready() or not layered_background.visible:
		return
	var viewport_size := size
	var width_scale := viewport_size.x / SOURCE_WIDTH
	var top_height := TOP_REFERENCE_HEIGHT * (viewport_size.x / REFERENCE_VIEWPORT_WIDTH)
	var bottom_height := BOTTOM_SOURCE_HEIGHT * width_scale
	var middle_height := maxf(viewport_size.y - top_height - bottom_height, 1.0)
	top_layer.position = Vector2.ZERO
	top_layer.size = Vector2(viewport_size.x, top_height)
	middle_layer.position = Vector2(0.0, top_height)
	middle_layer.size = Vector2(viewport_size.x, middle_height)
	bottom_layer.position = Vector2(0.0, top_height + middle_height)
	bottom_layer.size = Vector2(viewport_size.x, bottom_height)


func _refresh_monster() -> void:
	monster_origin.position = monster_position
	monster_origin.scale = Vector2.ONE * monster_display_scale
	monster_shadow.position = monster_position + shadow_offset_from_monster
	monster_sprite.texture = monster.sprite if monster != null else null
	monster_sprite.visible = monster_sprite.texture != null
	monster_shadow.visible = monster != null
	if monster == null or monster_sprite.texture == null:
		return
	monster_sprite.modulate = monster.display_color * monster.sprite_modulate
	monster_sprite.position = Vector2(
		monster.sprite_horizontal_offset,
		monster.sprite_height_offset
	)
	var texture_size := monster_sprite.texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		monster_sprite.scale = Vector2(
			monster.sprite_size.x / texture_size.x,
			monster.sprite_size.y / texture_size.y
		)
	monster_shadow.scale = Vector2(
		maxf(monster.shadow_scale.x, 0.0),
		maxf(monster.shadow_scale.y, 0.0)
	)
	_apply_screen_space_outline()


func _apply_screen_space_outline() -> void:
	if monster == null or not (monster_sprite.material is ShaderMaterial):
		return
	var global_sprite_scale := monster_sprite.get_global_transform_with_canvas().get_scale().abs()
	var average_scale := maxf((global_sprite_scale.x + global_sprite_scale.y) * 0.5, 0.001)
	var source_pixel_width := monster.outline_screen_size / average_scale
	(monster_sprite.material as ShaderMaterial).set_shader_parameter("outline_size", source_pixel_width)
