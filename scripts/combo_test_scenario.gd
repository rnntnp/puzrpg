class_name ComboTestScenario
extends Node

const TEST_CHAIN_MAX_LEVEL := 5
const TEST_COLUMN_X := 360.0
const FLOOR_Y := 825.0

var merge_game: MergeGame


func _ready() -> void:
	merge_game = get_parent() as MergeGame
	call_deferred("_start_if_requested")


func _start_if_requested() -> void:
	if not OS.is_debug_build() or not GameSession.consume_combo_test_request():
		return
	await _run_scenario()


func _run_scenario() -> void:
	merge_game.autoplay_bot.set_enabled(false)
	merge_game.set_input_enabled(false)
	var battle := merge_game.get_parent()
	if battle is Battle:
		battle.status_label.text = "콤보 테스트 준비"
		battle.status_label.modulate = Color("#ffd34e")

	for child in merge_game.get_active_balls():
		child.queue_free()
	await get_tree().physics_frame

	var next_y := FLOOR_Y
	for level_index in range(TEST_CHAIN_MAX_LEVEL - 1, -1, -1):
		var data := BallCatalog.get_ball(level_index)
		var radius: float = data.get_radius()
		next_y -= radius
		var ball := merge_game._spawn_ball(Vector2(TEST_COLUMN_X, next_y), level_index) as MergeBall
		ball.freeze = true
		next_y -= radius

	# 기존 공은 고정해 탑이 무너지지 않게 하고, 합성으로 생성된 공만 아래로 움직인다.
	await get_tree().create_timer(0.25, true, false, true).timeout
	merge_game.current_level = 0
	merge_game.next_level = 0
	merge_game._refresh_preview()
	merge_game.set_input_enabled(true)
	if battle is Battle:
		battle.status_label.text = "콤보 테스트 실행"
		battle.status_label.modulate = Color.WHITE
	merge_game.autoplay_drop_at(TEST_COLUMN_X)
