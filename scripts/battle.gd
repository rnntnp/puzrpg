class_name Battle
extends Node2D

const LevelDataClass = preload("res://scripts/level_data.gd")
const GameplayDebugSnapshotClass = preload("res://scripts/gameplay_debug_snapshot.gd")
const EnemyAttackEffect: StatusEffectData = preload("res://resources/effects/enemy_attack_countdown.tres")
const MergeAttackEffectScene = preload("res://scenes/merge_attack_effect.tscn")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const WaterHealthBarClass = preload("res://scripts/water_health_bar.gd")

@onready var left_fighter: Fighter = $UI/LeftFighter
@onready var right_fighter: Fighter = $UI/RightFighter
@onready var left_bar: WaterHealthBarClass = $UI/LeftHealthBar
@onready var right_bar: WaterHealthBarClass = $UI/RightHealthBar
@onready var title_label: Label = $UI/Title
@onready var status_label: Label = $UI/StatusLabel
@onready var enemy_progress_label: Label = $UI/EnemyProgress
@onready var left_status_effects: StatusEffectBar = $UI/LeftStatusEffects
@onready var right_status_effects: StatusEffectBar = $UI/RightStatusEffects
@onready var skill_durability_label: Label = $UI/SkillDurabilityLabel
@onready var gimmick_action_label: Label = $UI/GimmickActionLabel
@onready var gimmick_detail_label: Label = $UI/GimmickDetailLabel
@onready var background_artwork: TextureRect = $BackgroundArtwork
@onready var monster_action_controller = $MonsterActionController
@onready var merge_game = $MergeGame
@onready var exit_button: Button = $UI/ExitButton

var level_data: LevelDataClass
var current_enemy_index := 0
var battle_running := false
var level_finished := false
var enemy_drop_count := 0


func get_debug_snapshot() -> Dictionary:
	return GameplayDebugSnapshotClass.capture(self)


func _ready() -> void:
	exit_button.pressed.connect(_show_exit_confirmation)
	left_fighter.health_changed.connect(_on_left_health_changed)
	right_fighter.health_changed.connect(_on_right_health_changed)
	left_fighter.defeated.connect(_on_fighter_defeated)
	right_fighter.defeated.connect(_on_fighter_defeated)
	merge_game.game_over.connect(_on_merge_game_over)
	merge_game.overflow_triggered.connect(_on_overflow_triggered)
	merge_game.merge_attack_requested.connect(_on_merge_attack_requested)
	merge_game.turn_completed.connect(_on_ball_dropped)
	_load_level()
	_start_battle()


func _show_exit_confirmation() -> void:
	if level_finished:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "전투 나가기"
	dialog.dialog_text = "현재 전투를 포기하고 레벨 선택으로 돌아갈까요?\n진행 중인 전투는 저장되지 않습니다."
	dialog.ok_button_text = "레벨 선택"
	dialog.cancel_button_text = "계속 플레이"
	dialog.confirmed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(560, 250))


func _load_level() -> void:
	level_data = GameSession.get_current_level()
	if level_data == null or level_data.player_character == null or level_data.enemies.is_empty():
		push_error("레벨 전투 구성이 올바르지 않습니다.")
		return
	title_label.text = level_data.level_name
	current_enemy_index = 0
	level_finished = false
	if level_data.battle_background != null:
		background_artwork.texture = level_data.battle_background
	left_fighter.set_character_data(level_data.player_character)
	_load_enemy(current_enemy_index)
	merge_game.configure(
		level_data.ball_drop_time_limit,
		level_data.max_ball_level,
		level_data.ball_physics_speed,
		level_data.merge_push_force,
		level_data.merge_hit_stop_time_scale,
		level_data.merge_hit_stop_duration,
		level_data.chain_merge_delay
	)
	status_label.text = "전투 준비"
	status_label.modulate = Color("#ffd166")


func _load_enemy(index: int) -> void:
	var enemy_data = level_data.enemies[index]
	if level_data.test_gimmick != null:
		enemy_data = enemy_data.duplicate(true)
		enemy_data.max_health = level_data.test_gimmick.get_enemy_health(current_enemy_index)
		enemy_data.attack_power = level_data.test_gimmick.normal_attack_damage
		enemy_data.enemy_attack_drop_interval = level_data.test_gimmick.action_interval
	right_fighter.set_character_data(enemy_data)
	right_bar.fill_color = enemy_data.health_bar_color
	right_bar.queue_redraw()
	enemy_drop_count = 0
	enemy_progress_label.text = "적 %d / %d" % [index + 1, level_data.enemies.size()]
	monster_action_controller.configure(
		self, right_fighter, left_fighter, merge_game,
		right_status_effects, skill_durability_label
	)


func update_gimmick_ui(primary: String, detail: String) -> void:
	gimmick_action_label.visible = not primary.is_empty()
	gimmick_detail_label.visible = not detail.is_empty()
	gimmick_action_label.text = primary
	gimmick_detail_label.text = detail


func fail_gimmick_level(reason: String) -> void:
	if level_finished or not battle_running:
		return
	battle_running = false
	merge_game.set_input_enabled(false)
	status_label.text = reason
	status_label.modulate = Color("#ff6b6b")
	GameSession.set_battle_result(false, "%s · %s" % [level_data.level_name, reason])
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")


func _start_battle() -> void:
	battle_running = true
	status_label.text = "전투 중"
	status_label.modulate = Color.WHITE


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.set_health(health, maximum)


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.set_health(health, maximum)


func _on_ball_dropped() -> void:
	if not battle_running or not right_fighter.is_alive() or not left_fighter.is_alive():
		return
	monster_action_controller.on_ball_dropped()

func _on_merge_attack_requested(
	damage: int,
	combo_count: int,
	_base_points: int,
	origin: Vector2,
	ball_level: int
) -> void:
	if not battle_running or not left_fighter.is_alive() or not right_fighter.is_alive():
		print("[MERGE ATTACK SKIPPED] battle=%s | player_alive=%s | enemy_alive=%s" % [
			str(battle_running), str(left_fighter.is_alive()), str(right_fighter.is_alive())
		])
		return
	var effect = MergeAttackEffectScene.instantiate()
	add_child(effect)
	left_fighter.play_cast_animation()
	effect.hit.connect(_on_merge_projectile_hit.bind(ball_level, combo_count, origin))
	effect.play(origin, right_fighter.global_position, BallCatalogClass.get_ball(ball_level), damage, combo_count)


func _on_merge_projectile_hit(damage: int, ball_level: int, combo_count: int, merge_origin: Vector2) -> void:
	if not battle_running or not right_fighter.is_alive():
		return
	damage = monster_action_controller.route_player_damage(damage, ball_level, combo_count, merge_origin)
	if damage <= 0:
		return
	print("[MERGE ATTACK] damage=%d" % damage)
	right_fighter.take_damage(damage)


func _on_fighter_defeated(fighter: Fighter) -> void:
	battle_running = false
	merge_game.set_input_enabled(false)
	status_label.text = "적 처치!" if fighter == right_fighter else "전투 패배"
	await fighter.play_defeat_animation()
	if fighter == left_fighter:
		GameSession.set_battle_result(false, "%s 도전 실패" % level_data.level_name)
		get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
		return
	monster_action_controller.on_enemy_defeated()

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


func _on_overflow_triggered(damage: int) -> void:
	if not battle_running or not left_fighter.is_alive():
		return
	status_label.text = "오버플로우! HP -%d" % damage
	status_label.modulate = Color("#ff6677")
	left_fighter.take_damage(damage)
