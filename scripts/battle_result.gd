class_name BattleResult
extends Control

@export_file("*.tscn") var level_select_scene_path := "res://scenes/level_select.tscn"

@onready var result_label: Label = $Content/ResultLabel
@onready var detail_label: Label = $Content/DetailLabel
@onready var level_select_button: Button = $Content/LevelSelectButton


func _ready() -> void:
	result_label.text = "승리!" if GameSession.last_battle_won else "패배"
	result_label.modulate = Color("#ffd34e") if GameSession.last_battle_won else Color("#ff6577")
	detail_label.text = GameSession.last_result_title
	level_select_button.pressed.connect(_on_level_select_button_pressed)


func _on_level_select_button_pressed() -> void:
	level_select_button.disabled = true
	get_tree().change_scene_to_file(level_select_scene_path)
