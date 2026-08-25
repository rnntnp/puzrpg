class_name PlayerSkillController
extends Node

signal gauge_changed(current: int, maximum: int)
signal gauge_full
signal skill_used

var battle
var player: Fighter
var enemy: Fighter
var merge_game
var weakness_host
var skill_button: PlayerSkillButton
var skill_data: PlayerSkillData
var gauge_current := 0
var configured := false
var tutorial_skill_enabled := false


func configure(
	battle_node: Node,
	player_fighter: Fighter,
	game: Node,
	weakness_controller: Node,
	button: PlayerSkillButton
) -> void:
	cleanup()
	battle = battle_node
	player = player_fighter
	merge_game = game
	weakness_host = weakness_controller
	skill_button = button
	skill_data = player.character_data.player_skill as PlayerSkillData
	configured = skill_data != null
	skill_button.visible = configured
	if not configured:
		return
	if not merge_game.player_merge_registered.is_connected(_on_player_merge_registered):
		merge_game.player_merge_registered.connect(_on_player_merge_registered)
	if not skill_button.skill_pressed.is_connected(_on_skill_pressed):
		skill_button.skill_pressed.connect(_on_skill_pressed)
	gauge_current = 0
	skill_button.configure(skill_data.icon, skill_data.gauge_max, skill_data.display_name)
	_update_gauge_ui()


func set_enemy(enemy_fighter: Fighter) -> void:
	enemy = enemy_fighter


func on_enemy_defeated() -> void:
	enemy = null


func fill_gauge_for_tutorial() -> void:
	if not configured or skill_data == null:
		return
	gauge_current = skill_data.gauge_max
	_update_gauge_ui()


func set_tutorial_skill_enabled(enabled: bool) -> void:
	tutorial_skill_enabled = enabled


func cleanup() -> void:
	if is_instance_valid(merge_game) and merge_game.player_merge_registered.is_connected(_on_player_merge_registered):
		merge_game.player_merge_registered.disconnect(_on_player_merge_registered)
	if is_instance_valid(skill_button) and skill_button.skill_pressed.is_connected(_on_skill_pressed):
		skill_button.skill_pressed.disconnect(_on_skill_pressed)
	enemy = null
	configured = false


func _on_player_merge_registered(base_points: int, _result_level: int) -> void:
	if not configured or base_points <= 0 or not battle.battle_running or not player.is_alive():
		return
	var was_ready := gauge_current >= skill_data.gauge_max
	gauge_current = mini(skill_data.gauge_max, gauge_current + base_points)
	_update_gauge_ui()
	if not was_ready and gauge_current >= skill_data.gauge_max:
		gauge_full.emit()


func _on_skill_pressed() -> void:
	if not _can_use_skill():
		skill_button.play_blocked_feedback()
		return
	var total_turns: int = weakness_host.add_weakness_turns(
		skill_data.weakness_duration_turns
	)
	gauge_current = 0
	player.play_cast_animation()
	_update_gauge_ui()
	battle.status_label.text = "%s +%d턴 · 총 %d턴" % [
		skill_data.display_name,
		skill_data.weakness_duration_turns,
		total_turns,
	]
	battle.status_label.modulate = Color("#ffe066")
	skill_used.emit()


func _can_use_skill() -> bool:
	return (
		configured
		and gauge_current >= skill_data.gauge_max
		and is_instance_valid(enemy)
		and enemy.is_alive()
		and battle.battle_running
		and not battle.level_finished
		and (merge_game.can_accept_autoplay_drop() or tutorial_skill_enabled)
		and is_instance_valid(weakness_host)
		and weakness_host.has_method("add_weakness_turns")
	)


func _update_gauge_ui() -> void:
	if skill_data == null or not is_instance_valid(skill_button):
		return
	skill_button.set_gauge(gauge_current, skill_data.gauge_max)
	gauge_changed.emit(gauge_current, skill_data.gauge_max)
