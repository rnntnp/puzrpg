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
@onready var merge_game = $MergeGame

var level_data: LevelDataClass
var current_enemy_index := 0
var battle_running := false
var level_finished := false
var enemy_drop_count := 0


func _ready() -> void:
	left_fighter.health_changed.connect(_on_left_health_changed)
	right_fighter.health_changed.connect(_on_right_health_changed)
	left_fighter.defeated.connect(_on_fighter_defeated)
	right_fighter.defeated.connect(_on_fighter_defeated)
	merge_game.game_over.connect(_on_merge_game_over)
	merge_game.merge_attack_requested.connect(_on_merge_attack_requested)
	merge_game.ball_dropped.connect(_on_ball_dropped)
	_load_level()
	_start_battle()


func _load_level() -> void:
	level_data = GameSession.get_current_level()
	if level_data == null or level_data.player_character == null or level_data.enemies.is_empty():
		push_error("레벨 전투 구성이 올바르지 않습니다.")
		return
	title_label.text = level_data.level_name
	current_enemy_index = 0
	level_finished = false
	left_fighter.set_character_data(level_data.player_character)
	_load_enemy(current_enemy_index)
	merge_game.configure(level_data.ball_drop_time_limit, level_data.max_ball_level)
	status_label.text = "전투 준비"
	status_label.modulate = Color("#ffd166")
	_update_stats()


func _load_enemy(index: int) -> void:
	right_fighter.set_character_data(level_data.enemies[index])
	enemy_drop_count = 0
	enemy_progress_label.text = "적 %d / %d" % [index + 1, level_data.enemies.size()]
	_update_stats()


func _start_battle() -> void:
	battle_running = true
	status_label.text = "전투 중"
	status_label.modulate = Color.WHITE


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.max_value = maximum
	left_bar.value = health
	left_hp_label.text = "%s  %d / %d" % [left_fighter.display_name, health, maximum]


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.max_value = maximum
	right_bar.value = health
	right_hp_label.text = "%d / %d  %s" % [health, maximum, right_fighter.display_name]


func _update_stats() -> void:
	left_stats.text = "%s  머지 점수 공격" % left_fighter.display_name
	right_stats.text = "%s  공 %d개마다 공격" % [right_fighter.display_name, right_fighter.enemy_attack_drop_interval]

func _on_ball_dropped() -> void:
	if not battle_running or not right_fighter.is_alive() or not left_fighter.is_alive():
		return
	enemy_drop_count += 1
	if enemy_drop_count < right_fighter.enemy_attack_drop_interval:
		return
	enemy_drop_count = 0
	right_fighter.attack(left_fighter)

func _on_merge_attack_requested(damage: int, _combo_count: int, _base_points: int) -> void:
	if not battle_running or not left_fighter.is_alive() or not right_fighter.is_alive():
		print("[MERGE ATTACK SKIPPED] battle=%s | player_alive=%s | enemy_alive=%s" % [
			str(battle_running), str(left_fighter.is_alive()), str(right_fighter.is_alive())
		])
		return
	print("[MERGE ATTACK] damage=%d" % damage)
	left_fighter.attack_with_damage(right_fighter, damage)


func _on_fighter_defeated(fighter: Fighter) -> void:
	battle_running = false
	merge_game.set_input_enabled(false)
	status_label.text = "적 처치!" if fighter == right_fighter else "전투 패배"
	await fighter.play_defeat_animation()
	if fighter == left_fighter:
		GameSession.set_battle_result(false, "%s 도전 실패" % level_data.level_name)
		get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
		return

	current_enemy_index += 1
	if current_enemy_index < level_data.enemies.size():
		status_label.text = "다음 적 등장!"
		await get_tree().create_timer(0.7).timeout
		_load_enemy(current_enemy_index)
		merge_game.set_input_enabled(true)
		_start_battle()
		return

	level_finished = true
	status_label.text = "모든 적 처치!"
	await get_tree().create_timer(0.4).timeout
	GameSession.set_battle_result(true, "%s 완료" % level_data.level_name)
	GameSession.advance_to_next_level()
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")

func _on_merge_game_over() -> void:
	battle_running = false
	GameSession.set_battle_result(false, "%s · 머지 보드 게임오버" % level_data.level_name)
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
