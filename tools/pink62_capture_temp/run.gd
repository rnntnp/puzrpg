extends Node

var report: Array = []

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	GameSession.current_level_path = "res://resources/levels/test_circle_xpbd_pond.tres"
	for scenario in ["upper_ball", "lower_ball", "diagonal_ball", "between_balls"]:
		var battle = load("res://scenes/main.tscn").instantiate()
		add_child(battle)
		var board: MergeGame = battle.get_node("MergeGame")
		await get_tree().process_frame
		var layer = board.gimmick_overlay.get_children().filter(func(n): return n.get_script() == load("res://scripts/gimmicks/visuals/circle_xpbd_pond_layer.gd"))[0]
		board.danger_suppression_remaining = 600
		var at := Vector2(360, 440)
		var velocity := Vector2.ZERO
		if scenario == "upper_ball":
			velocity = Vector2(0, -400)
			board.spawn_gimmick_ball(6, at + Vector2(0, -165), Vector2(0, 120))
		elif scenario == "lower_ball":
			velocity = Vector2(0, 400)
			board.spawn_gimmick_ball(6, at + Vector2(0, 165), Vector2(0, -120))
		elif scenario == "diagonal_ball":
			at = Vector2(385, 505)
			velocity = Vector2(-310, -50)
			board.spawn_gimmick_ball(6, Vector2(245, 480), Vector2(140, -80))
			board.spawn_gimmick_ball(2, Vector2(463, 345), Vector2(-130, -70))
		else:
			board.spawn_gimmick_ball(6, at + Vector2(-165, 0), Vector2(400, 0))
			board.spawn_gimmick_ball(5, at + Vector2(155, 0), Vector2(-400, 0))
		var pink := board.spawn_gimmick_ball(4, at, velocity)
		var peak := 0.0
		for frame in 180:
			await get_tree().physics_frame
			var state: Dictionary = layer.states.get(pink.get_instance_id(), {})
			var current := 0.0
			for offset: Vector2 in state.get("offsets", []):
				current = maxf(current, offset.length())
			var valid_contact: bool = not state.get("contacts", []).is_empty()
			if current > peak + 0.15 and valid_contact:
				peak = current
				if DisplayServer.get_name() == "headless":
					continue
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				if image and not image.is_empty():
					image.save_png("res://artifacts/previews/pink02_stage62/%s.png" % scenario)
		report.append({"scenario": scenario, "maximum_control_offset_px": peak})
		battle.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open("res://artifacts/previews/pink02_stage62/capture_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PINK02 capture completed ", report)
	get_tree().paused = true
