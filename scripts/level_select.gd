class_name LevelSelect
extends Control

@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

@onready var level_name_label: Label = $Content/LevelName
@onready var placeholder_label: Label = $Content/LevelImage/PlaceholderText
@onready var start_button: Button = $Content/StartButton


func _ready() -> void:
	var level := GameSession.get_current_level()
	if level == null:
		start_button.disabled = true
		return
	level_name_label.text = level.level_name
	placeholder_label.text = level.image_placeholder
	start_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	get_tree().change_scene_to_file(battle_scene_path)
