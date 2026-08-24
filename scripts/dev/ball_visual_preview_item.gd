@tool
class_name BallVisualPreviewItem
extends Node2D

const ATLAS_TEXTURE := preload("res://assets/balls/generated/axolotl_only_ball_red_doteyes_rgba.png")
const ATLAS_CELL_SIZE := 418

@export_group("구슬")
@export_range(1, 9, 1) var stage_number: int = 1:
	set(value):
		stage_number = clampi(value, 1, 9)
		_refresh()
@export var tint_color: Color = Color(0.18, 0.74, 1.0, 1.0):
	set(value):
		tint_color = value
		_refresh()
@export_range(32.0, 120.0, 1.0) var preview_radius: float = 88.0:
	set(value):
		preview_radius = value
		_refresh()

@export_group("우파루파")
@export var axolotl_offset: Vector2 = Vector2.ZERO:
	set(value):
		axolotl_offset = value
		_refresh()
@export_range(0.5, 1.5, 0.01) var axolotl_scale: float = 1.0:
	set(value):
		axolotl_scale = value
		_refresh()

@onready var shell_base: Sprite2D = $ShellBase
@onready var axolotl: Sprite2D = $Axolotl
@onready var shell_shadow: Sprite2D = $ShellShadow
@onready var shell_gloss: Sprite2D = $ShellGloss
@onready var stage_label: Label = $StageLabel


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var stage_index := stage_number - 1
	var atlas := AtlasTexture.new()
	atlas.atlas = ATLAS_TEXTURE
	atlas.region = Rect2(
		float(stage_index % 3) * ATLAS_CELL_SIZE,
		float(stage_index / 3) * ATLAS_CELL_SIZE,
		ATLAS_CELL_SIZE,
		ATLAS_CELL_SIZE
	)
	axolotl.texture = atlas

	var diameter := preview_radius * 2.0
	var shell_scale := diameter / float(shell_base.texture.get_width())
	shell_base.scale = Vector2.ONE * shell_scale
	shell_base.modulate = tint_color
	shell_shadow.scale = Vector2.ONE * shell_scale
	shell_shadow.modulate = tint_color.darkened(0.62)
	shell_gloss.scale = Vector2.ONE * shell_scale
	shell_gloss.modulate = Color.WHITE
	axolotl.scale = Vector2.ONE * (diameter / ATLAS_CELL_SIZE) * axolotl_scale
	axolotl.position = axolotl_offset
	stage_label.position = Vector2(-70.0, preview_radius + 12.0)
	stage_label.text = "%d단계" % stage_number
