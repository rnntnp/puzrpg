class_name GameplayDebugSnapshot
extends RefCounted


static func capture(battle: Node) -> Dictionary:
	var merge_game: MergeGame = battle.merge_game as MergeGame
	var ball_states: Array[Dictionary] = []
	for child in merge_game.get_active_balls():
		if not child is MergeBall or child.is_queued_for_deletion():
			continue
		var ball := child as MergeBall
		ball_states.append({
			"id": ball.get_instance_id(),
			"level": ball.merge_level + 1,
			"position": _vector_to_dictionary(ball.position),
			"velocity": _vector_to_dictionary(ball.linear_velocity),
			"radius": ball.get_radius(),
			"sleeping": ball.sleeping,
			"merge_locked": ball.merge_locked,
		})

	ball_states.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return first.position.y > second.position.y
	)

	return {
		"scene": "battle",
		"level_name": battle.level_data.level_name if battle.level_data != null else "",
		"battle_running": battle.battle_running,
		"level_finished": battle.level_finished,
		"enemy_index": battle.current_enemy_index + 1,
		"enemy_count": battle.level_data.enemies.size() if battle.level_data != null else 0,
		"player": _fighter_state(battle.left_fighter),
		"enemy": _fighter_state(battle.right_fighter),
		"merge_game": {
			"can_drop": merge_game.can_accept_autoplay_drop(),
			"input_locked": merge_game.input_locked,
			"is_game_over": merge_game.is_game_over,
			"drop_sequence_active": merge_game.drop_sequence_active,
			"current_ball_level": merge_game.current_level + 1,
			"next_ball_level": merge_game.next_level + 1,
			"aim_x": merge_game.aim_x,
			"score": merge_game.score,
			"drop_time_remaining": merge_game.drop_time_remaining if merge_game.auto_drop_enabled else -1.0,
			"combo_count": merge_game.combo_count,
			"balls": ball_states,
		},
	}


static func _fighter_state(fighter: Fighter) -> Dictionary:
	return {
		"name": fighter.display_name,
		"health": fighter.current_health,
		"max_health": fighter.max_health,
		"alive": fighter.is_alive(),
	}


static func _vector_to_dictionary(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}
