class_name LoadingScreen
extends Control

@export_file("*.tscn") var next_scene_path := "res://scenes/level_select.tscn"
@export_range(0.1, 10.0, 0.1) var display_duration := 1.5


func _ready() -> void:
	await get_tree().create_timer(display_duration).timeout
	get_tree().change_scene_to_file(next_scene_path)
