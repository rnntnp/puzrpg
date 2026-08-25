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
@onready var right_applied_status_effects: StatusEffectBar = $UI/RightAppliedStatusEffects
@onready var player_skill_button: PlayerSkillButton = $UI/PlayerSkillButton
@onready var gimmick_action_label: Label = $UI/GimmickActionLabel
@onready var gimmick_detail_label: Label = $UI/GimmickDetailLabel
@onready var background_artwork: TextureRect = $BackgroundArtwork
@onready var layered_background: LayeredBattleBackground = $LayeredBackground
@onready var monster_action_controller = $MonsterActionController
@onready var player_skill_controller: PlayerSkillController = $PlayerSkillController
@onready var merge_game = $MergeGame
@onready var exit_button: Button = $UI/ExitButton
@onready var exit_confirmation_overlay: Control = $ExitConfirmationLayer/ExitConfirmationOverlay
@onready var exit_cancel_button: Button = $ExitConfirmationLayer/ExitConfirmationOverlay/Dialog/Margin/Content/Buttons/CancelButton
@onready var exit_confirm_button: Button = $ExitConfirmationLayer/ExitConfirmationOverlay/Dialog/Margin/Content/Buttons/ConfirmButton
@onready var enemy_hit_sfx: AudioStreamPlayer = $EnemyHitSfx
@onready var player_hit_sfx: AudioStreamPlayer = $PlayerHitSfx
@onready var ingestion_swallow_sfx: AudioStreamPlayer = $IngestionSwallowSfx
@onready var ingestion_spit_sfx: AudioStreamPlayer = $IngestionSpitSfx

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
var tutorial_skill_exercise_active := false
var tutorial_prompt_version := 0
var tutorial_drop_prompt_text := ""
var tutorial_drop_prompt: Label
var tutorial_prompt_tween: Tween
var enemy_transition_active := false
var pending_merge_attacks: Array[Dictionary] = []


func get_debug_snapshot() -> Dictionary:
	return GameplayDebugSnapshotClass.capture(self)


func _ready() -> void:
	exit_button.pressed.connect(_show_exit_confirmation)
	exit_cancel_button.pressed.connect(_hide_exit_confirmation)
	exit_confirm_button.pressed.connect(_exit_to_level_select)
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
	player_skill_controller.skill_used.connect(_on_tutorial_skill_used)
	_load_level()
	_start_battle()


func _show_exit_confirmation() -> void:
	if level_finished:
		return
	exit_confirmation_overlay.visible = true
	exit_cancel_button.grab_focus()


func _hide_exit_confirmation() -> void:
	exit_confirmation_overlay.visible = false
	exit_button.grab_focus()


func _exit_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _load_level() -> void:
	level_data = GameSession.get_current_level()
	if level_data == null or level_data.player_character == null or level_data.enemies.is_empty():
		push_error("레벨 전투 구성이 올바르지 않습니다.")
		return
	title_label.text = level_data.level_name
	current_enemy_index = 0
	level_finished = false
	enemy_transition_active = false
	pending_merge_attacks.clear()
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
	_apply_shadow_visual(left_fighter_shadow, left_fighter, level_data.player_character)
	player_skill_controller.configure(
		self, left_fighter, merge_game, monster_action_controller, player_skill_button
	)
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
	_apply_shadow_visual(right_fighter_shadow, right_fighter, enemy_data)
	right_bar.fill_color = enemy_data.health_bar_color
	right_bar.queue_redraw()
	enemy_drop_count = 0
	enemy_progress_label.text = "적 %d/%d" % [index + 1, level_data.enemies.size()]
	monster_action_controller.configure(
		self, right_fighter, left_fighter, merge_game,
		right_status_effects, right_applied_status_effects, right_bar
	)
	player_skill_controller.set_enemy(right_fighter)


func _apply_shadow_visual(shadow: Polygon2D, fighter: Fighter, character) -> void:
	if shadow == null or fighter == null or character == null:
		return
	shadow.position = fighter.position + character.shadow_offset
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
	enemy_transition_active = false
	pending_merge_attacks.clear()
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
	tutorial_sequence.play_control_tutorial(merge_game.get_drop_guide_global_x())


func _on_initial_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		tutorial_waiting_for_first_drop = not level_data.tutorial_turn_message.is_empty()
		_schedule_drop_prompt("클릭으로 방울을 떨어뜨리세요")


func _on_tutorial_control_page_shown() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		tutorial_waiting_for_first_drop = true


func _on_tutorial_player_ball_landed(_level: int, _drop_x: float) -> void:
	if not tutorial_waiting_for_first_drop:
		return
	tutorial_waiting_for_first_drop = false
	merge_game.set_input_enabled(false)
	_start_evolution_tutorial()


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.set_health(health, maximum)


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.set_health(health, maximum)


func _on_player_damage_received(amount: int) -> void:
	_play_damage_sfx(player_hit_sfx, amount, left_fighter.max_health, -5.0)


func _on_enemy_damage_received(amount: int) -> void:
	_play_damage_sfx(enemy_hit_sfx, amount, right_fighter.max_health, -4.0)


func _play_damage_sfx(player: AudioStreamPlayer, damage: int, target_max_health: int, base_volume_db: float) -> void:
	var damage_ratio := clampf(float(damage) / float(maxi(1, target_max_health)), 0.0, 1.0)
	var intensity := sqrt(damage_ratio)
	player.pitch_scale = lerpf(1.1, 0.82, intensity)
	player.volume_db = base_volume_db + lerpf(0.0, 3.0, intensity)
	player.play()


func show_player_damage_preview(damage: int) -> void:
	left_bar.set_predicted_damage(damage)


func clear_player_damage_preview() -> void:
	left_bar.clear_predicted_damage()


func play_ingestion_swallow_sfx() -> void:
	ingestion_swallow_sfx.play()


func play_ingestion_spit_sfx() -> void:
	ingestion_spit_sfx.play()


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
			_start_turn_tutorial()
	elif tutorial_merge_exercise_active:
			_schedule_drop_prompt("방울 위에 다른 방울을 떨어뜨려 보세요.")


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
		_start_combo_tutorial()


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
		_schedule_drop_prompt("방울 위에 다른 방울을 떨어뜨려 보세요.", 0.0)


func _start_attack_observation_tutorial() -> void:
	tutorial_attack_drops_remaining = 2
	_schedule_drop_prompt("방울을 떨어뜨려보세요")


func _start_enemy_intent_tutorial() -> void:
	var message := "적은 머리 위에 다음 행동과\n남은 턴 수를 보여줍니다."
	var intent_tutorial := StageIntroSequenceClass.new()
	add_child(intent_tutorial)
	intent_tutorial.sequence_finished.connect(_on_enemy_intent_tutorial_finished)
	intent_tutorial.play_tutorial(PackedStringArray([message]), merge_game.get_drop_guide_global_x())


func _start_enemy_intent_tutorial_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or level_finished or not battle_running:
		return
	_start_enemy_intent_tutorial()


func _on_enemy_intent_tutorial_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_input_enabled(true)
		tutorial_attack_drops_remaining = 1
		_schedule_drop_prompt("클릭으로 방울을 떨어뜨리세요")


func _on_tutorial_ball_dropped() -> void:
	monster_action_controller.on_player_ball_started()
	if tutorial_combo_demo_active:
		_hide_drop_prompt()
		merge_game.set_input_enabled(false)
		return
	if tutorial_attack_drops_remaining <= 0 and not tutorial_merge_exercise_active and not tutorial_waiting_for_first_drop:
		return
	_hide_drop_prompt()


func _schedule_drop_prompt(message: String, delay := 2.0) -> void:
	tutorial_prompt_version += 1
	tutorial_drop_prompt_text = message
	_show_drop_prompt_after_delay(tutorial_prompt_version, delay)


func _show_drop_prompt_after_delay(version: int, delay := 2.0) -> void:
	await get_tree().create_timer(delay).timeout
	if (
		version != tutorial_prompt_version
		or (tutorial_attack_drops_remaining <= 0 and not tutorial_merge_exercise_active and not tutorial_waiting_for_first_drop)
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
		_start_enemy_intent_tutorial_after_delay()
		return
	if tutorial_combo_demo_active and _merged_ball.merge_level >= 5:
		tutorial_combo_demo_active = false
		merge_game.set_drop_position_locked(false)
		merge_game.set_input_enabled(false)
		status_label.text = "콤보 공격 성공!"
		status_label.modulate = Color("#ffe07a")
		_start_skill_tutorial_after_delay()


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


func _start_skill_tutorial_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or level_finished or not battle_running:
		return
	player_skill_controller.fill_gauge_for_tutorial()
	var skill_tutorial := StageIntroSequenceClass.new()
	add_child(skill_tutorial)
	skill_tutorial.sequence_finished.connect(_on_skill_tutorial_sequence_finished)
	skill_tutorial.play_custom_spotlight_tutorial(
		"방울을 합성하면 정령들이 마나를 채워줍니다.\n마나가 가득 차면 클릭해\n스킬을 사용할 수 있습니다.",
		Vector2(181.0, 198.0), 62.0
	)


func _on_skill_tutorial_sequence_finished() -> void:
	if not battle_running or level_finished:
		return
	tutorial_skill_exercise_active = true
	player_skill_controller.set_tutorial_skill_enabled(true)
	_show_skill_drop_prompt()


func _show_skill_drop_prompt() -> void:
	_ensure_tutorial_drop_prompt()
	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()
	tutorial_drop_prompt.position = Vector2(120.0, 700.0)
	tutorial_drop_prompt.size = Vector2(480.0, 56.0)
	tutorial_drop_prompt.add_theme_font_size_override("font_size", 30)
	tutorial_drop_prompt.add_theme_constant_override("outline_size", 6)
	tutorial_drop_prompt.text = "스킬 아이콘을 클릭해 보세요."
	tutorial_drop_prompt.modulate.a = 1.0
	tutorial_drop_prompt.show()


func _on_tutorial_skill_used() -> void:
	if not tutorial_skill_exercise_active:
		return
	tutorial_skill_exercise_active = false
	player_skill_controller.set_tutorial_skill_enabled(false)
	_hide_drop_prompt()
	_start_weakness_tutorial()


func _start_weakness_tutorial() -> void:
	var weakness_tutorial := StageIntroSequenceClass.new()
	add_child(weakness_tutorial)
	weakness_tutorial.sequence_finished.connect(_on_weakness_tutorial_sequence_finished)
	weakness_tutorial.play_custom_box_spotlight_tutorial(
		"스킬로 적을 약화시키면,\n일정 턴 동안 받는 피해가 증가합니다.",
		Vector2(515.0, 150.0), Vector2(145.0, 82.0)
	)


func _on_weakness_tutorial_sequence_finished() -> void:
	var final_tutorial := StageIntroSequenceClass.new()
	add_child(final_tutorial)
	final_tutorial.sequence_finished.connect(_on_final_tutorial_sequence_finished)
	final_tutorial.play_custom_spotlight_tutorial(
		"수조의 정령들을 노리는\n적들을 물리치세요!", Vector2(530.0, 235.0), 210.0
	)


func _on_final_tutorial_sequence_finished() -> void:
	if battle_running and not level_finished:
		merge_game.set_fixed_drop_level(-1)
		merge_game.set_input_enabled(true)

func _on_merge_attack_requested(
	damage: int,
	combo_count: int,
	_base_points: int,
	origin: Vector2,
	ball_level: int
) -> void:
	if enemy_transition_active and left_fighter.is_alive():
		pending_merge_attacks.append({
			"damage": damage,
			"combo_count": combo_count,
			"origin": origin,
			"ball_level": ball_level,
		})
		print("[MERGE ATTACK DEFERRED] damage=%d | pending=%d" % [
			damage, pending_merge_attacks.size()
		])
		return
	if not battle_running or not left_fighter.is_alive() or not right_fighter.is_alive():
		print("[MERGE ATTACK SKIPPED] battle=%s | player_alive=%s | enemy_alive=%s" % [
			str(battle_running), str(left_fighter.is_alive()), str(right_fighter.is_alive())
		])
		return
	_launch_merge_projectile(damage, combo_count, origin, ball_level)


func _launch_merge_projectile(
	damage: int,
	combo_count: int,
	origin: Vector2,
	ball_level: int
) -> void:
	var effect = MergeAttackEffectScene.instantiate()
	add_child(effect)
	left_fighter.play_cast_animation()
	effect.hit.connect(_on_merge_projectile_hit.bind(ball_level, combo_count, origin))
	effect.play(origin, right_fighter.global_position, BallCatalogClass.get_ball(ball_level), damage, combo_count)


func _flush_pending_merge_attacks() -> void:
	if pending_merge_attacks.is_empty():
		return
	if not battle_running or not left_fighter.is_alive() or not right_fighter.is_alive():
		pending_merge_attacks.clear()
		return
	var attacks: Array[Dictionary] = pending_merge_attacks.duplicate()
	pending_merge_attacks.clear()
	for attack: Dictionary in attacks:
		var attack_origin: Vector2 = attack["origin"]
		_launch_merge_projectile(
			int(attack["damage"]),
			int(attack["combo_count"]),
			attack_origin,
			int(attack["ball_level"])
		)


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
	if fighter == right_fighter:
		enemy_transition_active = current_enemy_index + 1 < level_data.enemies.size()
		if not enemy_transition_active:
			pending_merge_attacks.clear()
		monster_action_controller.on_enemy_defeat_started()
	await fighter.play_defeat_animation()
	if fighter == left_fighter:
		enemy_transition_active = false
		pending_merge_attacks.clear()
		GameSession.set_battle_result(false, "%s 도전 실패" % level_data.level_name)
		get_tree().change_scene_to_file("res://scenes/battle_result.tscn")
		return
	player_skill_controller.on_enemy_defeated()
	monster_action_controller.on_enemy_defeated()

	current_enemy_index += 1
	if current_enemy_index < level_data.enemies.size():
		status_label.text = "다음 적 등장!"
		await get_tree().create_timer(0.7).timeout
		_load_enemy(current_enemy_index)
		merge_game.set_input_enabled(true)
		_start_battle()
		enemy_transition_active = false
		_flush_pending_merge_attacks()
		return

	enemy_transition_active = false
	pending_merge_attacks.clear()
	level_finished = true
	status_label.text = "모든 적 처치!"
	await get_tree().create_timer(0.4).timeout
	GameSession.set_battle_result(true, "%s 완료" % level_data.level_name)
	GameSession.advance_to_next_level()
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")

func _on_merge_game_over() -> void:
	battle_running = false
	enemy_transition_active = false
	pending_merge_attacks.clear()
	GameSession.set_battle_result(false, "%s · 머지 보드 게임오버" % level_data.level_name)
	get_tree().change_scene_to_file("res://scenes/battle_result.tscn")


func _on_overflow_triggered(damage: int) -> void:
	if not battle_running or not left_fighter.is_alive():
		return
	status_label.text = "오버플로우! HP -%d" % damage
	status_label.modulate = Color("#ff6677")
	left_fighter.take_damage(damage)
