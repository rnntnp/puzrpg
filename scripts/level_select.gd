class_name LevelSelect
extends Control

@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

@onready var start_button: Button = $Content/StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	get_tree().change_scene_to_file(battle_scene_path)
