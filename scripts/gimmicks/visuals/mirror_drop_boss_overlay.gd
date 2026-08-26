class_name MirrorDropBossOverlay
extends Node2D

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const LEGACY_VISUAL_SCENE = preload("res://scenes/balls/visuals/ball_visual_base.tscn")
const VISUAL_DESIGN_SIZE := 418.0
const PHASE_NORMAL := 0
const PHASE_MIRROR := 1

var bounds := Rect2()
var phase := PHASE_NORMAL
var mirror_x := 0.0
var drop_y := 0.0
var mirror_action_active := false
var preview_level := -1
var preview_visual: Node2D
var preview_background: Sprite2D


func _ready() -> void:
	preview_visual = Node2D.new()
	preview_visual.name = "MirrorBallPreview"
	preview_visual.visible = false
	add_child(preview_visual)
	preview_background = Sprite2D.new()
	preview_background.name = "BlackBackground"
	preview_background.modulate = Color.BLACK
	preview_background.z_index = -1
	preview_visual.add_child(preview_background)


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
	if is_instance_valid(preview_visual):
		preview_visual.position = Vector2(mirror_x, drop_y)
		preview_visual.visible = phase == PHASE_MIRROR and not mirror_action_active
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
	if not is_instance_valid(preview_visual) or ball_level == preview_level:
		return
	preview_level = ball_level
	var ball_data: Resource = BallCatalogClass.get_ball(ball_level)
	if ball_data == null:
		preview_visual.visible = false
		return
	for child in preview_visual.get_children():
		if child != preview_background:
			child.free()
	var scene: PackedScene = ball_data.visual_scene if ball_data.visual_scene != null else LEGACY_VISUAL_SCENE
	var visual := scene.instantiate() as Node2D
	# Only the shell background is black. Keep gloss and the inner sprite at
	# their authored colors; stage 1 is the exception because its large inner
	# sprite hides nearly all of the black background.
	visual.modulate = Color.WHITE
	preview_visual.add_child(visual)
	var visual_scale: float = ball_data.get_radius() * 2.0 / VISUAL_DESIGN_SIZE
	visual.scale = Vector2.ONE * visual_scale
	var shell_outline := visual.get_node_or_null("ShellOutline") as Sprite2D
	if shell_outline != null and shell_outline.texture != null:
		preview_background.texture = shell_outline.texture
		preview_background.texture_filter = shell_outline.texture_filter
		preview_background.position = shell_outline.position * visual_scale
		preview_background.rotation = shell_outline.rotation
		preview_background.scale = shell_outline.scale * visual_scale
	else:
		preview_background.texture = null
	var preview_axolotl := visual.get_node_or_null("Axolotl") as Sprite2D
	if preview_axolotl != null and ball_level == 0:
		preview_axolotl.modulate = Color.BLACK
	if ball_data.visual_scene == null:
		var axolotl := visual.get_node_or_null("Axolotl") as Sprite2D
		var shell_base := visual.get_node_or_null("ShellBase") as Sprite2D
		var shell_shadow := visual.get_node_or_null("ShellShadow") as Sprite2D
		if axolotl != null:
			axolotl.texture = ball_data.sprite
			axolotl.modulate = ball_data.sprite_modulate
			if ball_data.sprite != null:
				var texture_size: Vector2 = ball_data.sprite.get_size()
				axolotl.scale = Vector2(VISUAL_DESIGN_SIZE / texture_size.x, VISUAL_DESIGN_SIZE / texture_size.y)
		if shell_base != null:
			shell_base.modulate = ball_data.glow_color
		if shell_shadow != null:
			shell_shadow.modulate = ball_data.glow_color.darkened(0.62)
