extends Node2D
## Stage 64 soft-body board composed with existing campaign enemy handlers.
const Reflections = preload("res://scripts/gimmicks/visuals/pond_surface_reflection_layer.gd")
const Soft = preload("res://scripts/gimmicks/visuals/deformable_pond_layer.gd")
const Fallback = preload("res://scripts/gimmicks/visuals/deformable_pond_xpbd_layer.gd")
const Settings = preload("res://resources/deformable_pond_physics.tres")
const Occlusion = preload("res://scripts/gimmicks/visuals/deformable_pond_occlusion.gd")
const Pool = preload("res://scripts/gimmicks/visuals/deformable_pond_pool.gd")
const Bursts = preload("res://scripts/gimmicks/visuals/deformable_pond_bursts.gd")
const Launcher = preload("res://scripts/gimmicks/visuals/directional_gravity_launcher.gd")
const PlayerVisual = preload("res://scripts/gimmicks/visuals/compound_pond_player.gd")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
var board: MergeGame
var launcher: Node2D
var player_visual: Node2D
var reflections: Node2D
var warp: Node2D
var occlusion: Node2D
var ball_pool: Node2D
var bursts: Node2D

func _ready() -> void:
	board = get_parent() as MergeGame
	launcher = Launcher.new()
	add_child(launcher)
	launcher.configure(board, Settings)
	board.board_launch_controller = launcher
	board.ball_entry_position_provider = _entry_position
	board.combo_demo_provider = _prepare_combo_demo
	board.ball_dropped.connect(_configure_balls)
	board.merge_completed.connect(_on_merge_completed)
	board.gimmick_state_reset.connect(_restore_board_mode)
	var battle := board.get_parent() as Battle
	if battle != null:
		player_visual = PlayerVisual.new()
		add_child(player_visual)
		player_visual.reparent(battle.left_fighter, false)
		player_visual.configure(battle.left_fighter, 1.17, true)
	reflections = Reflections.new()
	add_child(reflections)
	reflections.configure(board, Settings.rendering_settings, true)
	var use_native:=ClassDB.class_exists("QWorldNode") and Settings.physics_backend=="QuarkPhysics"
	warp = Soft.new() if use_native else Fallback.new()
	add_child(warp)
	warp.configure(board, Settings)
	launcher.flight_velocity_integrator=warp.integrate_flight_velocity
	launcher.prediction_step_seconds=warp.step_seconds if use_native else 1.0/(60.0*Settings.solver_substeps)
	if use_native:launcher.prediction_collision_mask=Soft.QUERY_LAYER
	occlusion=Occlusion.new()
	occlusion.show_debug_controls=false
	add_child(occlusion)
	occlusion.configure(warp)
	bursts=Bursts.new()
	add_child(bursts)
	bursts.configure(board,Settings)
	if use_native:
		ball_pool=Pool.new()
		add_child(ball_pool)
		ball_pool.configure(board,warp,reflections,launcher)

func _configure_balls() -> void:
	if is_instance_valid(launcher): launcher.configure_active_balls()

func _entry_position(level: int, x: float) -> Vector2:
	var ball_data: Resource = BallCatalogClass.get_ball(level)
	var radius: float = ball_data.get_radius()
	return Vector2(x, board.board_inner_bottom - radius - Settings.spawn_floor_clearance)

func _on_merge_completed(_ball: MergeBall) -> void:
	_configure_balls()

func _prepare_combo_demo() -> void:
	board.clear_active_balls()
	var center: float=(board.board_inner_left+board.board_inner_right)*0.5
	var edge: float=board.drop_position_y+2.0
	for level in range(4,-1,-1):
		var ball: MergeBall=board.spawn_gimmick_ball(level,Vector2(center,edge+80.0))
		if ball==null:continue
		if not warp.states.has(ball.get_instance_id()):warp._register(ball)
		var state: Dictionary=warp.states[ball.get_instance_id()]
		var top:=INF
		var bottom:=-INF
		for point in state.rest:
			top=minf(top,point.y)
			bottom=maxf(bottom,point.y)
		ball.position=Vector2(center,edge-top)
		if state.has("native"):
			warp._import_native(state)
			warp._read_native(state)
			warp._publish(state)
		ball.freeze=true
		ball.sleeping=true
		edge=ball.position.y+bottom+6.0
	launcher.direction=Vector2.UP
	launcher.throw_power=0.45

func _restore_board_mode() -> void:
	# Enemy-handler cleanup resynchronizes ordinary board geometry. Keep the
	# persistent launcher and inverted overflow boundary across that cleanup.
	if not is_instance_valid(board) or not is_instance_valid(launcher): return
	board.set_process_unhandled_input(false)
	board.danger_height_direction = -1.0
	board.danger_line_y = board.board_inner_bottom - (board.board_inner_bottom - board.drop_position_y) * board.danger_line_height_ratio
	board.danger_line.configure(board.board_inner_left, board.board_inner_right, board.danger_line_y)
	# Ordinary enemy cleanup restores Godot layers; retain the soft solver's
	# query-only colliders and integrator across those existing transitions.
	if is_instance_valid(warp) and ClassDB.class_exists("QWorldNode"):
		for state: Dictionary in warp.states.values():
			if not is_instance_valid(state.ball) or state.ball.merge_locked:continue
			state.ball.collision_layer=Soft.QUERY_LAYER
			state.ball.collision_mask=0
			state.ball.custom_integrator=true
			state.ball.freeze=state.ball.is_ice_frozen
	_configure_balls()

func _exit_tree() -> void:
	if is_instance_valid(bursts):bursts.shutdown()
	if is_instance_valid(ball_pool):ball_pool.shutdown()
	if is_instance_valid(board):
		if board.board_launch_controller == launcher: board.board_launch_controller = null
		if board.ball_entry_position_provider == _entry_position: board.ball_entry_position_provider = Callable()
		if board.combo_demo_provider == _prepare_combo_demo:board.combo_demo_provider=Callable()
		if board.ball_dropped.is_connected(_configure_balls): board.ball_dropped.disconnect(_configure_balls)
		if board.merge_completed.is_connected(_on_merge_completed): board.merge_completed.disconnect(_on_merge_completed)
		if board.gimmick_state_reset.is_connected(_restore_board_mode): board.gimmick_state_reset.disconnect(_restore_board_mode)
	if is_instance_valid(player_visual):
		player_visual.restore()
		player_visual.queue_free()
	# Reverse installation order: restore warp materials before reflection flags.
	if is_instance_valid(warp): warp.restore_balls()
	if is_instance_valid(reflections): reflections.restore_visuals()
	if is_instance_valid(launcher) and is_instance_valid(board) and is_instance_valid(board.danger_line) and is_instance_valid(board.guide_line):
		launcher.restore_input()
