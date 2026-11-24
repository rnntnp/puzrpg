extends Node2D
## Stage 62 board controls/presentation composed with campaign enemy handlers.
const Reflections = preload("res://scripts/gimmicks/visuals/pond_surface_reflection_layer.gd")
const Warp = preload("res://scripts/gimmicks/visuals/circle_xpbd_pond_layer.gd")
const Settings = preload("res://resources/circle_xpbd_pond_physics.tres")
const Launcher = preload("res://scripts/gimmicks/visuals/directional_gravity_launcher.gd")
const PlayerVisual = preload("res://scripts/gimmicks/visuals/compound_pond_player.gd")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
var board: MergeGame
var launcher: Node2D
var player_visual: Node2D
var reflections: Node2D
var warp: Node2D

func _ready() -> void:
	board = get_parent() as MergeGame
	launcher = Launcher.new()
	add_child(launcher)
	launcher.configure(board, Settings)
	board.board_launch_controller = launcher
	board.ball_entry_position_provider = _entry_position
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
	warp = Warp.new()
	add_child(warp)
	warp.configure(board, Settings)

func _configure_balls() -> void:
	if is_instance_valid(launcher): launcher.configure_active_balls()

func _entry_position(level: int, x: float) -> Vector2:
	var ball_data: Resource = BallCatalogClass.get_ball(level)
	var radius: float = ball_data.get_radius()
	return Vector2(x, board.board_inner_bottom - radius - Settings.spawn_floor_clearance)

func _on_merge_completed(_ball: MergeBall) -> void:
	_configure_balls()

func _restore_board_mode() -> void:
	# Enemy-handler cleanup resynchronizes ordinary board geometry. Keep the
	# persistent launcher and inverted overflow boundary across that cleanup.
	if not is_instance_valid(board) or not is_instance_valid(launcher): return
	board.set_process_unhandled_input(false)
	board.danger_height_direction = -1.0
	board.danger_line_y = board.board_inner_bottom - (board.board_inner_bottom - board.drop_position_y) * board.danger_line_height_ratio
	board.danger_line.configure(board.board_inner_left, board.board_inner_right, board.danger_line_y)
	_configure_balls()

func _exit_tree() -> void:
	if is_instance_valid(board):
		if board.board_launch_controller == launcher: board.board_launch_controller = null
		if board.ball_entry_position_provider == _entry_position: board.ball_entry_position_provider = Callable()
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
