class_name BattleResult
extends Control

@export_file("*.tscn") var level_select_scene_path := "res://scenes/level_select.tscn"

@onready var content: Panel = $Content
@onready var victory_artwork: TextureRect = $VictoryArtwork
@onready var victory_level_select_button: Button = $VictoryLevelSelectButton
@onready var defeat_artwork: TextureRect = $DefeatArtwork
@onready var defeat_level_select_button: Button = $DefeatLevelSelectButton
@onready var result_label: Label = $Content/ResultLabel
@onready var detail_label: Label = $Content/DetailLabel
@onready var level_select_button: Button = $Content/LevelSelectButton


func _ready() -> void:
	var battle_won := GameSession.last_battle_won
	content.visible = false
	victory_artwork.visible = battle_won
	victory_level_select_button.visible = battle_won
	defeat_artwork.visible = not battle_won
	defeat_level_select_button.visible = not battle_won
	result_label.text = "승리!" if battle_won else "패배"
	result_label.modulate = Color("#ffd34e") if battle_won else Color("#ff6577")
	detail_label.text = GameSession.last_result_title
	level_select_button.pressed.connect(_on_level_select_button_pressed)
	victory_level_select_button.pressed.connect(_on_level_select_button_pressed)
	defeat_level_select_button.pressed.connect(_on_level_select_button_pressed)
	if GameSession.developer_autoplay_enabled:
		level_select_button.disabled = true
		victory_level_select_button.disabled = true
		defeat_level_select_button.disabled = true
		level_select_button.text = "자동 진행 중..."
		_auto_continue()


func _on_level_select_button_pressed() -> void:
	level_select_button.disabled = true
	get_tree().change_scene_to_file(level_select_scene_path)

func _auto_continue() -> void:
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and GameSession.developer_autoplay_enabled:
		get_tree().change_scene_to_file(level_select_scene_path)
