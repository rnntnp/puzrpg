class_name LayeredBattleBackground
extends Control

const SOURCE_WIDTH := 941.0
const BOTTOM_SOURCE_HEIGHT := 322.0
## 720px 기준 돌 발판 윗면을 캐릭터 발끝보다 약 50px 위에 둔다.
const REFERENCE_VIEWPORT_WIDTH := 720.0
const TOP_REFERENCE_HEIGHT := 508.0

var top_reference_height := TOP_REFERENCE_HEIGHT

@onready var top_layer: TextureRect = $Top
@onready var middle_layer: TextureRect = $Middle
@onready var bottom_layer: TextureRect = $Bottom


func _ready() -> void:
	get_viewport().size_changed.connect(_layout_layers)
	_layout_layers()


func configure(
	top_texture: Texture2D,
	middle_texture: Texture2D,
	bottom_texture: Texture2D,
	reference_top_height := TOP_REFERENCE_HEIGHT
) -> void:
	top_layer.texture = top_texture
	middle_layer.texture = middle_texture
	bottom_layer.texture = bottom_texture
	top_reference_height = maxf(reference_top_height, 1.0)
	visible = top_texture != null and middle_texture != null and bottom_texture != null
	_layout_layers()


func _layout_layers() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size

	var width_scale := viewport_size.x / SOURCE_WIDTH
	var top_height := top_reference_height * (viewport_size.x / REFERENCE_VIEWPORT_WIDTH)
	var bottom_height := BOTTOM_SOURCE_HEIGHT * width_scale
	var middle_height := maxf(viewport_size.y - top_height - bottom_height, 1.0)

	top_layer.position = Vector2.ZERO
	top_layer.size = Vector2(viewport_size.x, top_height)
	middle_layer.position = Vector2(0.0, top_height)
	middle_layer.size = Vector2(viewport_size.x, middle_height)
	bottom_layer.position = Vector2(0.0, top_height + middle_height)
	bottom_layer.size = Vector2(viewport_size.x, bottom_height)
