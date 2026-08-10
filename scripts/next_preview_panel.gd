@tool
class_name NextPreviewPanel
extends Control

@onready var editor_preview: Sprite2D = $PreviewHolder/EditorPreview


func _ready() -> void:
	editor_preview.visible = editor_preview.texture != null


func set_preview_data(ball_data: Resource) -> void:
	if editor_preview == null:
		return
	if ball_data == null:
		editor_preview.visible = false
		return
	editor_preview.texture = ball_data.sprite
	editor_preview.modulate = ball_data.sprite_modulate
	editor_preview.visible = editor_preview.texture != null
