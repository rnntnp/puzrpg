class_name Battle
extends Node2D

const LevelDataClass = preload("res://scripts/level_data.gd")
const GameplayDebugSnapshotClass = preload("res://scripts/gameplay_debug_snapshot.gd")
const EnemyAttackEffect: StatusEffectData = preload("res://resources/effects/enemy_attack_countdown.tres")
const MergeAttackEffectScene = preload("res://scenes/merge_attack_effect.tscn")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const WaterHealthBarClass = preload("res://scripts/water_health_bar.gd")
const StageIntroSequenceClass = preload("res://scripts/stage_intro_sequence.gd")

@onready var left_fighter: Fighter = $UI/LeftFighter
@onready var right_fighter: Fighter = $UI/RightFighter
@onready var left_fighter_shadow: Polygon2D = $UI/LeftFighterShadow
@onready var right_fighter_shadow: Polygon2D = $UI/RightFighterShadow
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
@onready var layered_background: LayeredBattleBackground = $LayeredBackground
@onready var monster_action_controller = $MonsterActionController
@onready var merge_game = $MergeGame
@onready var exit_button: Button = $UI/ExitButton
@onready var enemy_hit_sfx: AudioStreamPlayer = $EnemyHitSfx
@onready var player_hit_sfx: AudioStreamPlayer = $PlayerHitSfx

var level_data: LevelDataClass
var current_enemy_index := 0
var battle_running := false
var level_finished := false
var enemy_drop_count := 0
var opening_sequence_played := false
var tutorial_sequence_played := false
var tutorial_waiting_for_first_drop := false
var tutorial_turn_explanation_pending := false
var tutorial_attack_drops_remaining := 0
var tutorial_merge_exercise_active := false
var tutorial_combo_demo_active := false
var tutorial_prompt_version := 0
var tutorial_drop_prompt_text := ""
var tutorial_drop_prompt: Label
var tutorial_prompt_tween: Tween


func get_debug_snapshot() -> Dictionary:
	return GameplayDebugSnapshotClass.capture(self)


func _ready() -> void:
	exit_button.pressed.connect(_show_exit_confirmation)
	left_fighter.health_changed.connect(_on_left_health_changed)
	right_fighter.health_changed.connect(_on_right_health_changed)
	left_fighter.damage_received.connect(_on_player_damage_received)
	right_fighter.damage_received.connect(_on_enemy_damage_received)
	left_fighter.defeated.connect(_on_fighter_defeated)
	right_fighter.defeated.connect(_on_fighter_defeated)
	merge_game.game_over.connect(_on_merge_game_over)
	merge_game.overflow_triggered.connect(_on_overflow_triggered)
	merge_game.merge_attack_requested.connect(_on_merge_attack_requested)
	merge_game.ball_dropped.connect(_on_tutorial_ball_dropped)
	merge_game.turn_completed.connect(_on_ball_dropped)
	merge_game.player_ball_landed.connect(_on_tutorial_player_ball_landed)
	merge_game.merge_completed.connect(_on_tutorial_merge_completed)
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
	if (
		level_data.battle_background_top != null
		and level_data.battle_background_middle != null
		and level_data.battle_background_bottom != null
	):
		background_artwork.visible = false
		layered_background.configure(
			level_data.battle_background_top,
			level_data.battle_background_middle,
			level_data.battle_background_bottom,
			level_data.battle_background_top_height
		)
	else:
		layered_background.visible = false
		background_artwork.visible = true
	if level_data.battle_background != null:
		background_artwork.texture = level_data.battle_background
	left_fighter.set_character_data(level_data.player_character)
	_apply_shadow_scale(left_fighter_shadow, level_data.player_character)
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
	if level_data.fixed_drop_level >= 0:
		merge_game.set_fixed_drop_level(level_data.fixed_drop_level)
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
	_apply_shadow_scale(right_fighter_shadow, enemy_data)
	right_bar.fill_color = enemy_data.health_bar_color
	right_bar.queue_redraw()
	enemy_drop_count = 0
	enemy_progress_label.text = "적 %d/%d" % [index + 1, level_data.enemies.size()]
	monster_action_controller.configure(
		self, right_fighter, left_fighter, merge_game,
		right_status_effects, skill_durability_label
	)


func _apply_shadow_scale(shadow: Polygon2D, character) -> void:
	if shadow == null or character == null:
		return
	shadow.scale = Vector2(
		maxf(character.shadow_scale.x, 0.0),
		maxf(character.shadow_scale.y, 0.0)
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
	if not opening_sequence_played and not level_data.opening_sequence.is_empty():
		opening_sequence_played = true
		merge_game.set_input_enabled(false)
		status_label.text = "시작 연출"
		status_label.modulate = Color("#ffd166")
		var intro_sequence := StageIntroSequenceClass.new()
		add_child(intro_sequence)
		intro_sequence.sequence_finished.connect(_on_opening_sequence_finished)
		intro_sequence.play_story(level_data.opening_sequence, level_data.opening_story_images)
		return
	battle_running = true
	merge_game.set_input_enabled(true)
	status_label.text = ""
	status_label.modulate = Color.WHITE
	_start_tutorial_sequence()


func _on_opening_sequence_finished() -> void:
	_start_battle()


func _start_tutorial_sequence() -> void:
	if tutorial_sequence_played or level_data.tutorial_sequence.is_empty():
		return
	tutorial_sequence_played = true
	merge_game.set_input_enabled(false)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or not battle_running or level_finished:
		return
	var tutorial_sequence := StageIntroSequenceClass.new()
	add_child(tutorial_sequence)
	tutorial_sequence.sequence_finished.connect(_on_initial_tutorial_sequence_finished)
	tutorial_sequence.tutorial_control_page_shown.connect(_on_tutorial_control_page_shown)
	tutorial_sequence.play_tutorial(
		level_data.tutorial_sequence,
		merge_game.get_drop_guide_global_x()
	)


func _on_initial_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		tutorial_waiting_for_first_drop = not level_data.tutorial_turn_message.is_empty()


func _on_tutorial_control_page_shown() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)


func _on_tutorial_player_ball_landed(_level: int, _drop_x: float) -> void:
	if not tutorial_waiting_for_first_drop:
		return
	tutorial_waiting_for_first_drop = false
	tutorial_turn_explanation_pending = true
	merge_game.set_input_enabled(false)


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.set_health(health, maximum)


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.set_health(health, maximum)


func _on_player_damage_received(_amount: int) -> void:
	player_hit_sfx.play()


func _on_enemy_damage_received(_amount: int) -> void:
	enemy_hit_sfx.play()


func show_player_damage_preview(damage: int) -> void:
	left_bar.set_predicted_damage(damage)


func clear_player_damage_preview() -> void:
	left_bar.clear_predicted_damage()


func _on_ball_dropped() -> void:
	if not battle_running or not right_fighter.is_alive() or not left_fighter.is_alive():
		return
	monster_action_controller.on_ball_dropped()
	if tutorial_turn_explanation_pending:
		tutorial_turn_explanation_pending = false
		_start_turn_tutorial()
	elif tutorial_attack_drops_remaining > 0:
		tutorial_attack_drops_remaining -= 1
		if tutorial_attack_drops_remaining > 0:
			_schedule_drop_prompt("방울을 떨어뜨려보세요")
		else:
			merge_game.set_input_enabled(false)
			_start_evolution_tutorial()
	elif tutorial_merge_exercise_active:
			_schedule_drop_prompt("방울을 다른 방울 위에 떨어뜨려 보세요")


func _start_turn_tutorial() -> void:
	if level_data.tutorial_turn_message.is_empty() or level_finished:
		return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or level_finished or not battle_running:
		return
	var turn_tutorial := StageIntroSequenceClass.new()
	add_child(turn_tutorial)
	turn_tutorial.sequence_finished.connect(_on_turn_tutorial_sequence_finished)
	turn_tutorial.play_turn_tutorial(level_data.tutorial_turn_message)


func _on_turn_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		_start_attack_observation_tutorial()


func _start_evolution_tutorial() -> void:
	if level_data.tutorial_evolution_messages.is_empty() or level_finished:
		return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or level_finished or not battle_running:
		return
	var evolution_tutorial := StageIntroSequenceClass.new()
	add_child(evolution_tutorial)
	evolution_tutorial.sequence_finished.connect(_on_evolution_tutorial_sequence_finished)
	evolution_tutorial.play_evolution_tutorial(level_data.tutorial_evolution_messages)


func _on_evolution_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		tutorial_merge_exercise_active = true
		_schedule_drop_prompt("방울을 다른 방울 위에 떨어뜨려 보세요")


func _start_attack_observation_tutorial() -> void:
	tutorial_attack_drops_remaining = 2
	_schedule_drop_prompt("방울을 떨어뜨려보세요")


func _on_tutorial_ball_dropped() -> void:
	if tutorial_combo_demo_active:
		merge_game.set_input_enabled(false)
		return
	if tutorial_attack_drops_remaining <= 0 and not tutorial_merge_exercise_active:
		return
	_hide_drop_prompt()


func _schedule_drop_prompt(message: String) -> void:
	tutorial_prompt_version += 1
	tutorial_drop_prompt_text = message
	_show_drop_prompt_after_delay(tutorial_prompt_version)


func _show_drop_prompt_after_delay(version: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if (
		version != tutorial_prompt_version
		or (tutorial_attack_drops_remaining <= 0 and not tutorial_merge_exercise_active)
		or not battle_running
		or level_finished
		or not merge_game.can_accept_autoplay_drop()
	):
		return
	_ensure_tutorial_drop_prompt()
	tutorial_drop_prompt.position = Vector2(120.0, 700.0)
	tutorial_drop_prompt.size = Vector2(480.0, 56.0)
	tutorial_drop_prompt.add_theme_font_size_override("font_size", 30)
	tutorial_drop_prompt.add_theme_constant_override("outline_size", 6)
	tutorial_drop_prompt.text = tutorial_drop_prompt_text
	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()
	tutorial_drop_prompt.modulate.a = 0.0
	tutorial_drop_prompt.show()
	tutorial_prompt_tween = create_tween()
	tutorial_prompt_tween.tween_property(tutorial_drop_prompt, "modulate:a", 1.0, 0.35)


func _ensure_tutorial_drop_prompt() -> void:
	if tutorial_drop_prompt != null:
		return
	tutorial_drop_prompt = Label.new()
	tutorial_drop_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 1.0))
	tutorial_drop_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.14, 0.95))
	tutorial_drop_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_drop_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_drop_prompt.z_index = 20
	$UI.add_child(tutorial_drop_prompt)


func _show_combo_drop_prompt() -> void:
	_ensure_tutorial_drop_prompt()
	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()
	tutorial_drop_prompt.position = Vector2(70.0, 620.0)
	tutorial_drop_prompt.size = Vector2(580.0, 60.0)
	tutorial_drop_prompt.add_theme_font_size_override("font_size", 25)
	tutorial_drop_prompt.add_theme_constant_override("outline_size", 6)
	tutorial_drop_prompt.text = "방울을 떨어뜨려 연속 합성을 해보세요"
	tutorial_drop_prompt.modulate.a = 1.0
	tutorial_drop_prompt.show()


func _hide_drop_prompt() -> void:
	tutorial_prompt_version += 1
	if tutorial_drop_prompt == null or not tutorial_drop_prompt.visible:
		return
	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()
	tutorial_prompt_tween = create_tween()
	tutorial_prompt_tween.tween_property(tutorial_drop_prompt, "modulate:a", 0.0, 0.15)
	tutorial_prompt_tween.tween_callback(tutorial_drop_prompt.hide)


func _on_tutorial_merge_completed(_merged_ball: MergeBall) -> void:
	if tutorial_merge_exercise_active:
		tutorial_merge_exercise_active = false
		_hide_drop_prompt()
		merge_game.set_input_enabled(false)
		_start_combo_tutorial()
		return
	if tutorial_combo_demo_active and _merged_ball.merge_level >= 5:
		tutorial_combo_demo_active = false
		merge_game.set_drop_position_locked(false)
		merge_game.set_input_enabled(true)
		status_label.text = "콤보 공격 성공!"
		status_label.modulate = Color("#ffe07a")


func _start_combo_tutorial() -> void:
	merge_game.set_input_enabled(false)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or level_finished or not battle_running:
		return
	merge_game.prepare_combo_demo_stack()
	var combo_tutorial := StageIntroSequenceClass.new()
	add_child(combo_tutorial)
	combo_tutorial.sequence_finished.connect(_on_combo_tutorial_sequence_finished)
	combo_tutorial.play_combo_tutorial("연속으로 방울을 합성하면\n더 강한 콤보 공격을 가합니다.")


func _on_combo_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		tutorial_combo_demo_active = true
		merge_game.set_drop_position_locked(true)
		merge_game.set_input_enabled(true)
		_show_combo_drop_prompt()

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
