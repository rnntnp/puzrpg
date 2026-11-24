extends "res://scripts/gimmicks/handlers/pond_surface_reflection_handler.gd"
const QuarkLayer = preload("res://scripts/gimmicks/visuals/deformable_pond_layer.gd")
const XPBDLayer = preload("res://scripts/gimmicks/visuals/deformable_pond_xpbd_layer.gd")
const PlayerVisual = preload("res://scripts/gimmicks/visuals/compound_pond_player.gd")
const DebugLayer = preload("res://scripts/gimmicks/visuals/deformable_pond_debug.gd")
var soft_balls: Node2D
var player_visual: Node2D
var ball_pool: Node2D
var burst_renderer: Node2D

func _on_configured() -> void:
	super._on_configured()
	player_visual = attach_visual_layer(PlayerVisual.new())
	player_visual.reparent(player, false)
	player_visual.configure(player, 1.17, true)
	var use_quark: bool = tuning.physics_backend == "QuarkPhysics" and ClassDB.class_exists("QWorldNode")
	soft_balls = attach_visual_layer(QuarkLayer.new() if use_quark else XPBDLayer.new())
	soft_balls.configure(merge_game, tuning)
	var occlusion := attach_visual_layer(preload("res://scripts/gimmicks/visuals/deformable_pond_occlusion.gd").new())
	occlusion.configure(soft_balls)
	burst_renderer=attach_visual_layer(preload("res://scripts/gimmicks/visuals/deformable_pond_bursts.gd").new())
	burst_renderer.configure(merge_game,tuning)
	if use_quark:
		ball_pool=attach_visual_layer(preload("res://scripts/gimmicks/visuals/deformable_pond_pool.gd").new())
		ball_pool.configure(merge_game,soft_balls,reflections,launcher)
	launcher.flight_velocity_integrator = soft_balls.integrate_flight_velocity
	launcher.prediction_step_seconds = soft_balls.step_seconds if use_quark else 1.0 / (60.0 * tuning.solver_substeps)
	if use_quark: launcher.prediction_collision_mask = QuarkLayer.QUERY_LAYER
	var backend := "Quark · %d 입자 · 실제 소프트바디" % tuning.quark_particle_count if use_quark else "XPBD · 6 입자 · 실제 소프트바디 (대체)"
	if not use_quark: push_warning("Stage 64: QuarkPhysics unavailable; using real XPBD soft-body fallback.")
	var debug := attach_visual_layer(DebugLayer.new())
	debug.configure(merge_game, soft_balls, tuning, backend)

func _integrate_reflection_with_outline() -> bool:
	return true

func _on_cleanup() -> void:
	if is_instance_valid(burst_renderer):burst_renderer.shutdown()
	if is_instance_valid(ball_pool):ball_pool.shutdown()
	if is_instance_valid(player_visual): player_visual.restore()
	if is_instance_valid(soft_balls): soft_balls.restore_balls()
	super._on_cleanup()
