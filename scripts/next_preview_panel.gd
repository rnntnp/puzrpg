@tool
class_name NextPreviewPanel
extends Control

@onready var visual_preview: Node2D = $PreviewHolder/VisualPreview


func _ready() -> void:
	visual_preview.visible = visual_preview.get_child_count() > 0


func set_preview_data(ball_data: Resource) -> void:
	if visual_preview == null:
		return
	for child in visual_preview.get_children():
		child.queue_free()
	if ball_data == null:
		visual_preview.visible = false
		return
	var scene: PackedScene = ball_data.visual_scene
	if scene == null:
		visual_preview.visible = false
		return
	visual_preview.add_child(scene.instantiate())
	visual_preview.visible = true
