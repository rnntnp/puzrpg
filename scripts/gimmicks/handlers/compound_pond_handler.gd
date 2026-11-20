extends "res://scripts/gimmicks/handlers/pond_surface_reflection_handler.gd"

const CompoundConfig = preload("res://scripts/gimmicks/configs/compound_pond_config.gd")
const CompoundLauncher = preload("res://scripts/gimmicks/visuals/compound_pond_launcher.gd")
const CompoundColliders = preload("res://scripts/gimmicks/visuals/compound_pond_colliders.gd")
const CompoundLayer = preload("res://scripts/gimmicks/visuals/compound_pond_layer.gd")
const CollisionDebug = preload("res://scripts/gimmicks/visuals/compound_pond_collision_debug.gd")
const PlayerVisual = preload("res://scripts/gimmicks/visuals/compound_pond_player.gd")
var colliders: RefCounted
var soft_balls: Node2D
var player_visual: Node2D

func _on_configured() -> void:
	# Reuse loadout, enemy turns, launcher and reflection paths without creating
	# the stage 62 layer or changing its scripts/resources.
	tuning = data.tuning if data.tuning != null else CompoundConfig.new()
	player_visual = attach_visual_layer(PlayerVisual.new())
	player_visual.reparent(player, false)
	player_visual.configure(player)
	colliders = CompoundColliders.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(CompoundLauncher.new())
	launcher.colliders = colliders
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	last_effect = ""
	_on_enemy_changed()
	reflections = attach_visual_layer(ReflectionLayer.new())
	reflections.configure(merge_game, tuning.rendering_settings, true)
	soft_balls = attach_visual_layer(CompoundLayer.new())
	soft_balls.colliders = colliders
	soft_balls.configure(merge_game, tuning)
	var collision_debug := attach_visual_layer(CollisionDebug.new())
	collision_debug.configure(merge_game, tuning)

func _on_cleanup() -> void:
	if is_instance_valid(player_visual): player_visual.restore()
	if is_instance_valid(soft_balls): soft_balls.restore_balls()
	super._on_cleanup()
	if colliders != null: colliders.restore()

func _exit_tree() -> void:
	if is_instance_valid(soft_balls): soft_balls.restore_balls()
	if colliders != null: colliders.restore()
