extends Node

const LEVEL_CATALOG: LevelCatalog = preload("res://resources/catalogs/main_level_catalog.tres")


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []
	for level_path in LEVEL_CATALOG.automated_smoke_level_paths:
		GameSession.current_level_path = level_path
		var packed := load("res://scenes/main.tscn") as PackedScene
		var battle := packed.instantiate() as Battle
		add_child(battle)
		await get_tree().process_frame
		await get_tree().process_frame
		if battle == null or battle.level_data == null or battle.level_data.test_gimmick == null:
			failures.append("%s: scene/configure failed" % level_path)
			continue
		battle.level_data.test_gimmick.animation_duration = 0.02
		var game := battle.merge_game as MergeGame
		game.set_input_enabled(false)
		var bounds := game.get_base_board_bounds()
		for index in 5:
			var x := bounds.position.x + 70.0 + float(index) * 92.0
			var y := bounds.end.y - 80.0 - float(index % 2) * 90.0
			game.spawn_gimmick_ball(index, Vector2(x, y))
		await get_tree().physics_frame
		var controller := battle.monster_action_controller.test_gimmick_controller as TestGimmickController
		var simulated_turns := 0
		while controller.debug_special_execution_count < 2 and simulated_turns < 50:
			controller.on_turn_completed()
			simulated_turns += 1
			while controller.busy:
				await get_tree().process_frame
			await get_tree().process_frame
		if controller.debug_special_execution_count < 2:
			failures.append("%s: two-cycle execution failed" % level_path)
		else:
			print("[GIMMICK SMOKE PASS] %s | two cycles in %d turns" % [level_path, simulated_turns])
		controller.cleanup()
		battle.queue_free()
		await get_tree().process_frame
	if failures.is_empty():
		print("[GIMMICK SMOKE COMPLETE] %d/%d levels, two cycles each" % [LEVEL_CATALOG.automated_smoke_level_paths.size(), LEVEL_CATALOG.automated_smoke_level_paths.size()])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
