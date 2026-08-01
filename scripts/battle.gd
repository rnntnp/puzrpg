class_name Battle
extends Node2D

const LevelDataClass = preload("res://scripts/level_data.gd")

@onready var left_fighter: Fighter = $UI/LeftFighter
@onready var right_fighter: Fighter = $UI/RightFighter
@onready var left_bar: ProgressBar = $UI/LeftHealthBar
@onready var right_bar: ProgressBar = $UI/RightHealthBar
@onready var left_hp_label: Label = $UI/LeftHealthLabel
@onready var right_hp_label: Label = $UI/RightHealthLabel
@onready var left_stats: Label = $UI/LeftStats
@onready var right_stats: Label = $UI/RightStats
@onready var title_label: Label = $UI/Title
@onready var status_label: Label = $UI/StatusLabel
@onready var enemy_progress_label: Label = $UI/EnemyProgress
@onready var start_button: Button = $UI/StartButton

var level_data: LevelDataClass
var current_enemy_index := 0
var battle_running := false
var level_finished := false


func _ready() -> void:
	left_fighter.health_changed.connect(_on_left_health_changed)
	right_fighter.health_changed.connect(_on_right_health_changed)
	left_fighter.defeated.connect(_on_fighter_defeated)
	right_fighter.defeated.connect(_on_fighter_defeated)
	start_button.pressed.connect(_on_start_button_pressed)
	_load_level()


func _process(delta: float) -> void:
	if not battle_running:
		return
	if left_fighter.advance_cooldown(delta):
		left_fighter.attack(right_fighter)
	if battle_running and right_fighter.advance_cooldown(delta):
		right_fighter.attack(left_fighter)


func _load_level() -> void:
	level_data = GameSession.get_current_level()
	if level_data == null or level_data.player_character == null or level_data.enemies.is_empty():
		push_error("레벨 전투 구성이 올바르지 않습니다.")
		start_button.disabled = true
		return
	title_label.text = level_data.level_name
	current_enemy_index = 0
	level_finished = false
	left_fighter.set_character_data(level_data.player_character)
	_load_enemy(current_enemy_index)
	status_label.text = "준비"
	status_label.modulate = Color("#ffd166")
	start_button.text = "전투 시작"
	start_button.disabled = false
	_update_stats()


func _load_enemy(index: int) -> void:
	right_fighter.set_character_data(level_data.enemies[index])
	enemy_progress_label.text = "적 %d / %d" % [index + 1, level_data.enemies.size()]
	_update_stats()


func _start_battle() -> void:
	battle_running = true
	left_fighter.cooldown_remaining = left_fighter.attack_cooldown
	right_fighter.cooldown_remaining = right_fighter.attack_cooldown
	status_label.text = "전투 중"
	status_label.modulate = Color.WHITE
	start_button.disabled = true
	start_button.text = "전투 중..."


func _on_start_button_pressed() -> void:
	if level_finished:
		return
	if not left_fighter.is_alive():
		_load_level()
	_start_battle()


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.max_value = maximum
	left_bar.value = health
	left_hp_label.text = "%s  %d / %d" % [left_fighter.display_name, health, maximum]


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.max_value = maximum
	right_bar.value = health
	right_hp_label.text = "%d / %d  %s" % [health, maximum, right_fighter.display_name]


func _update_stats() -> void:
	left_stats.text = "%s\n공격력 %d\n쿨타임 %.1f초" % [left_fighter.display_name, left_fighter.attack_power, left_fighter.attack_cooldown]
	right_stats.text = "%s\n공격력 %d\n쿨타임 %.1f초" % [right_fighter.display_name, right_fighter.attack_power, right_fighter.attack_cooldown]


func _on_fighter_defeated(fighter: Fighter) -> void:
	battle_running = false
	if fighter == left_fighter:
		status_label.text = "패배"
		status_label.modulate = Color("#ff6577")
		start_button.disabled = true
		GameSession.set_battle_result(false, "%s 도전 실패" % level_data.level_name)
		get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
		return

	current_enemy_index += 1
	if current_enemy_index < level_data.enemies.size():
		status_label.text = "다음 적 등장!"
		await get_tree().create_timer(0.7).timeout
		_load_enemy(current_enemy_index)
		_start_battle()
		return

	level_finished = true
	status_label.text = "레벨 승리!"
	status_label.modulate = Color("#ffd166")
	enemy_progress_label.text = "모든 적 처치"
	GameSession.set_battle_result(true, "%s 완료" % level_data.level_name)
	GameSession.advance_to_next_level()
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
