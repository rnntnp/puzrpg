class_name MirrorDropBossOverlay
extends Node2D

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const VISUAL_DESIGN_SIZE := 418.0
const PHASE_NORMAL := 0
const PHASE_MIRROR := 1

var bounds := Rect2()
var phase := PHASE_NORMAL
var mirror_x := 0.0
var drop_y := 0.0
var mirror_action_active := false
var preview_level := -1
var preview_sprite: Sprite2D


func _ready() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "MirrorBallPreview"
	preview_sprite.modulate = Color(0.0, 0.0, 0.0, 0.58)
	preview_sprite.visible = false
	add_child(preview_sprite)


func show_state(
	board_bounds: Rect2,
	phase_value: int,
	ghost_x: float,
	spawn_y: float,
	action_active: bool,
	ball_level: int
) -> void:
	bounds = board_bounds
	phase = phase_value
	mirror_x = ghost_x
	drop_y = spawn_y
	mirror_action_active = action_active
	_sync_preview_shape(ball_level)
	if is_instance_valid(preview_sprite):
		preview_sprite.position = Vector2(mirror_x, drop_y) + preview_sprite.get_meta(&"outline_offset", Vector2.ZERO)
		preview_sprite.visible = phase == PHASE_MIRROR and not mirror_action_active
	queue_redraw()


func _draw() -> void:
	if phase != PHASE_MIRROR:
		return
	var center_x: float = bounds.get_center().x
	draw_dashed_line(
		Vector2(center_x, bounds.position.y),
		Vector2(center_x, bounds.end.y),
		Color(0.75, 0.9, 1.0, 0.30),
		2.0,
		9.0
	)


func _sync_preview_shape(ball_level: int) -> void:
	if not is_instance_valid(preview_sprite) or ball_level == preview_level:
		return
	preview_level = ball_level
	var ball_data: Resource = BallCatalogClass.get_ball(ball_level)
	if ball_data == null or ball_data.visual_scene == null:
		preview_sprite.visible = false
		return
	var visual := ball_data.visual_scene.instantiate() as Node2D
	var shell_outline := visual.get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline == null or shell_outline.texture == null:
		visual.free()
		preview_sprite.visible = false
		return
	var visual_scale: float = ball_data.get_radius() * 2.0 / VISUAL_DESIGN_SIZE
	preview_sprite.texture = shell_outline.texture
	preview_sprite.texture_filter = shell_outline.texture_filter
	preview_sprite.rotation = shell_outline.rotation
	preview_sprite.scale = shell_outline.scale * visual_scale
	preview_sprite.set_meta(&"outline_offset", shell_outline.position * visual_scale)
	visual.free()
