class_name BattleResult
extends Control

@export_file("*.tscn") var level_select_scene_path := "res://scenes/level_select.tscn"

@onready var background: TextureRect = $Background
@onready var victory_glow_effect: TextureRect = $VictoryGlowEffect
@onready var defeat_top_gradient_effect: TextureRect = $DefeatTopGradientEffect
@onready var character_sprite: TextureRect = $CharacterSprite
@onready var result_label: Label = $HeaderFrame/ResultLabel
@onready var stage_name_label: Label = $StageTitleFrame/StageNameLabel
@onready var detail_label: Label = $InfoPanel/DetailLabel
@onready var left_info_title: Label = $InfoPanel/LeftCard/Title
@onready var left_info_value: Label = $InfoPanel/LeftCard/Value
@onready var right_info_title: Label = $InfoPanel/RightCard/Title
@onready var right_info_value: Label = $InfoPanel/RightCard/Value
@onready var level_select_button: Button = $LevelSelectButton


func _ready() -> void:
	var battle_won := GameSession.last_battle_won
	var level = GameSession.get_last_battle_level()
	if level != null:
		background.texture = level.battle_background if level.battle_background != null else level.level_select_preview
		stage_name_label.text = level.level_name
		left_info_value.text = level.stage_gimmick_name
		right_info_value.text = level.reward_name if battle_won else "다시 도전해요"
	victory_glow_effect.visible = battle_won
	defeat_top_gradient_effect.visible = not battle_won
	character_sprite.texture = preload("res://assets/ui/results/characters/player_victory_handdrawn.png") if battle_won else preload("res://assets/ui/results/characters/player_defeat_handdrawn.png")
	result_label.text = "스테이지 클리어!" if battle_won else "도전 실패"
	result_label.modulate = Color("#0b3766")
	left_info_title.text = "스테이지 기믹"
	right_info_title.text = "클리어 보상" if battle_won else "다음 도전"
	detail_label.text = GameSession.last_result_title
	level_select_button.pressed.connect(_on_level_select_button_pressed)
	if GameSession.developer_autoplay_enabled:
		level_select_button.disabled = true
		level_select_button.text = "자동 진행 중..."
		_auto_continue()


func _on_level_select_button_pressed() -> void:
	level_select_button.disabled = true
	get_tree().change_scene_to_file(level_select_scene_path)

func _auto_continue() -> void:
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and GameSession.developer_autoplay_enabled:
		get_tree().change_scene_to_file(level_select_scene_path)
