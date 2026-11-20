extends "res://scripts/gimmicks/visuals/directional_gravity_launcher.gd"
## Install preview and spawned shapes before the inherited compound shape casts.
var colliders: RefCounted

func configure_active_balls() -> void:
	if is_instance_valid(game) and colliders != null:
		for ball in game.get_active_balls():
			if ball is MergeBall and not ball.merge_locked: colliders.install(ball, tuning)
		if is_instance_valid(game.preview_ball): colliders.install(game.preview_ball, tuning)
	super.configure_active_balls()

func _update_landing_prediction() -> void:
	if colliders != null and is_instance_valid(game.preview_ball):
		colliders.install(game.preview_ball, tuning)
	super._update_landing_prediction()

func _update_preview() -> void:
	if colliders != null and is_instance_valid(game.preview_ball):
		colliders.install(game.preview_ball, tuning)
	super._update_preview()
