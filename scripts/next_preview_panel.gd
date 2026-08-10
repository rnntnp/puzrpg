@tool
class_name NextPreviewPanel
extends Control

@onready var editor_preview: Sprite2D = $PreviewHolder/EditorPreview


func _ready() -> void:
	if not Engine.is_editor_hint():
		editor_preview.visible = false


func apply_preview_layout(ball: MergeBall) -> void:
	if ball == null or editor_preview == null:
		return
	ball.position = editor_preview.position
	ball.rotation = editor_preview.rotation
	ball.scale = editor_preview.scale
