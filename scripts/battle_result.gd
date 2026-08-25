class_name BattleResult
extends Control

@export_file("*.tscn") var level_select_scene_path := "res://scenes/level_select.tscn"
@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

@onready var background: TextureRect = $Background
@onready var victory_glow_effect: TextureRect = $VictoryGlowEffect
@onready var defeat_top_gradient_effect: TextureRect = $DefeatTopGradientEffect
@onready var character_sprite: TextureRect = $CharacterSprite
@onready var result_label: Label = $HeaderFrame/ResultLabel
@onready var stage_name_label: Label = $StageTitleFrame/StageNameLabel
@onready var reward_panel: Panel = $RewardPanel
@onready var gold_value: Label = $RewardPanel/GoldValue
@onready var max_combo_value: Label = $StatsPanel/MaxComboValue
@onready var damage_value: Label = $StatsPanel/DamageValue
@onready var retry_button: Button = $RetryButton
@onready var level_select_button: Button = $LevelSelectButton
@onready var debug_preview_bar: HBoxContainer = $DebugPreviewBar
@onready var debug_victory_button: Button = $DebugPreviewBar/VictoryButton
@onready var debug_defeat_button: Button = $DebugPreviewBar/DefeatButton

var _button_tweens: Dictionary = {}
var _pressed_buttons: Dictionary = {}
var _character_motion_tween: Tween
var _character_rest_position := Vector2.ZERO


func _ready() -> void:
	var battle_won := GameSession.last_battle_won
	debug_preview_bar.visible = OS.is_debug_build()
	debug_victory_button.pressed.connect(_show_debug_victory)
	debug_defeat_button.pressed.connect(_show_debug_defeat)
	_character_rest_position = character_sprite.position
	character_sprite.pivot_offset = character_sprite.size * 0.5
	_setup_result_button(level_select_button)
	_setup_result_button(retry_button)
	_apply_result_state(battle_won)
	level_select_button.pressed.connect(_on_level_select_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	if GameSession.developer_autoplay_enabled:
		level_select_button.disabled = true
		retry_button.disabled = true
		level_select_button.text = "자동 진행 중..."
		_auto_continue()


func _apply_result_state(battle_won: bool, use_preview_values := false) -> void:
	var level = GameSession.get_last_battle_level()
	if level != null:
		background.texture = level.battle_background if level.battle_background != null else level.level_select_preview
		stage_name_label.text = level.level_name
	victory_glow_effect.visible = battle_won
	defeat_top_gradient_effect.visible = not battle_won
	reward_panel.visible = battle_won
	retry_button.visible = not battle_won
	character_sprite.texture = preload("res://assets/ui/results/characters/player_victory_handdrawn.png") if battle_won else preload("res://assets/ui/results/characters/player_defeat_handdrawn.png")
	_play_character_motion(battle_won)
	result_label.text = "스테이지 클리어!" if battle_won else "도전 실패"
	result_label.modulate = Color("#0b3766")
	var gold := 150 if use_preview_values and battle_won else GameSession.last_result_gold
	var max_combo := 12 if use_preview_values else GameSession.last_result_max_combo
	var damage_dealt := 12430 if use_preview_values else GameSession.last_result_damage_dealt
	gold_value.text = _format_number(gold)
	max_combo_value.text = "×%s" % _format_number(max_combo)
	damage_value.text = _format_number(damage_dealt)


func _play_character_motion(battle_won: bool) -> void:
	if _character_motion_tween != null and _character_motion_tween.is_valid():
		_character_motion_tween.kill()
	character_sprite.position = _character_rest_position
	character_sprite.scale = Vector2.ONE
	_character_motion_tween = create_tween().set_loops()
	if battle_won:
		_character_motion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_character_motion_tween.tween_property(
			character_sprite, "position:y", _character_rest_position.y - 11.0, 0.75
		)
		_character_motion_tween.tween_property(
			character_sprite, "position:y", _character_rest_position.y + 4.0, 0.75
		)
	else:
		_character_motion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_character_motion_tween.tween_property(
			character_sprite, "scale", Vector2(1.035, 0.93), 0.42
		)
		_character_motion_tween.tween_property(
			character_sprite, "scale", Vector2.ONE, 0.52
		)
		_character_motion_tween.tween_interval(0.28)


func _show_debug_victory() -> void:
	_apply_result_state(true, true)


func _show_debug_defeat() -> void:
	_apply_result_state(false, true)


func _format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _setup_result_button(button: Button) -> void:
	button.mouse_entered.connect(_on_result_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_result_button_mouse_exited.bind(button))
	button.button_down.connect(_on_result_button_down.bind(button))
	button.button_up.connect(_on_result_button_up.bind(button))
	button.focus_entered.connect(_on_result_button_mouse_entered.bind(button))
	button.focus_exited.connect(_on_result_button_focus_exited.bind(button))
	button.resized.connect(_update_button_pivot.bind(button))
	_update_button_pivot.call_deferred(button)


func _update_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_result_button_mouse_entered(button: Button) -> void:
	if not button.disabled and not _pressed_buttons.get(button.get_instance_id(), false):
		_animate_result_button(button, Vector2.ONE * 1.025, Color(1.06, 1.06, 1.06, 1.0))


func _on_result_button_mouse_exited(button: Button) -> void:
	if not _pressed_buttons.get(button.get_instance_id(), false):
		_animate_result_button(button, Vector2.ONE, Color.WHITE)


func _on_result_button_down(button: Button) -> void:
	if button.disabled:
		return
	_pressed_buttons[button.get_instance_id()] = true
	_animate_result_button(button, Vector2.ONE * 0.97, Color(0.92, 0.92, 0.92, 1.0), 0.06)


func _on_result_button_up(button: Button) -> void:
	_pressed_buttons[button.get_instance_id()] = false
	var hovered := button.is_hovered() and not button.disabled
	_animate_result_button(
		button,
		Vector2.ONE * 1.025 if hovered else Vector2.ONE,
		Color(1.06, 1.06, 1.06, 1.0) if hovered else Color.WHITE
	)


func _on_result_button_focus_exited(button: Button) -> void:
	if not button.is_hovered() and not _pressed_buttons.get(button.get_instance_id(), false):
		_animate_result_button(button, Vector2.ONE, Color.WHITE)


func _animate_result_button(button: Button, target_scale: Vector2, target_color: Color, duration := 0.1) -> void:
	var button_id := button.get_instance_id()
	var old_tween: Tween = _button_tweens.get(button_id)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)
	tween.tween_property(button, "self_modulate", target_color, duration)
	_button_tweens[button_id] = tween


func _on_level_select_button_pressed() -> void:
	level_select_button.disabled = true
	get_tree().change_scene_to_file(level_select_scene_path)


func _on_retry_button_pressed() -> void:
	retry_button.disabled = true
	if GameSession.prepare_last_battle_retry():
		get_tree().change_scene_to_file(battle_scene_path)

func _auto_continue() -> void:
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and GameSession.developer_autoplay_enabled:
		get_tree().change_scene_to_file(level_select_scene_path)
