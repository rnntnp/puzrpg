class_name LevelSelect
extends Control

@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

@onready var level_name_label: Label = $Content/LevelName
@onready var placeholder_label: Label = $Content/LevelImage/PlaceholderText
@onready var start_button: Button = $Content/StartButton
@onready var autoplay_button: Button = $Content/AutoplayButton


func _ready() -> void:
	var level := GameSession.get_current_level()
	if level == null:
		start_button.disabled = true
		return
	level_name_label.text = level.level_name
	placeholder_label.text = level.image_placeholder
	start_button.pressed.connect(_on_start_button_pressed)
	autoplay_button.visible = OS.is_debug_build()
	autoplay_button.text = "개발 자동 플레이: ON" if GameSession.developer_autoplay_enabled else "개발 자동 플레이: OFF"
	autoplay_button.pressed.connect(_on_autoplay_button_pressed)
	if GameSession.developer_autoplay_enabled:
		_auto_start_level()


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	get_tree().change_scene_to_file(battle_scene_path)

func _on_autoplay_button_pressed() -> void:
	GameSession.developer_autoplay_enabled = not GameSession.developer_autoplay_enabled
	autoplay_button.text = "개발 자동 플레이: ON" if GameSession.developer_autoplay_enabled else "개발 자동 플레이: OFF"
	if GameSession.developer_autoplay_enabled:
		_auto_start_level()

func _auto_start_level() -> void:
	start_button.disabled = true
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree() and GameSession.developer_autoplay_enabled:
		get_tree().change_scene_to_file(battle_scene_path)
