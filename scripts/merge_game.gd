class_name MergeGame
extends Node2D

signal game_over
signal merge_attack_requested(
	damage: int,
	combo_count: int,
	base_points: int,
	origin: Vector2,
	ball_level: int,
	drop_sequence_id: int
)
signal ball_dropped
signal turn_completed
signal overflow_triggered(damage: int)
signal ingestion_target_replaced(ball: MergeBall)
signal ice_telegraph_merge_resolved(result_ball: MergeBall, source_ids: Array[int], marked_source_count: int)
signal merge_completed(merged_ball: MergeBall)
signal merge_registered(result_level: int, origin: Vector2, chain_index: int, source_ids: Array[int], involved_cursed: bool)
signal player_merge_registered(base_points: int, result_level: int)
signal player_ball_landed(level: int, drop_x: float)
signal external_merge_damage_requested(
	damage: int,
	combo_count: int,
	base_points: int,
	origin: Vector2,
	ball_level: int
)

const BallScene = preload("res://scenes/merge_ball.tscn")
const MergeBurstEffectScene = preload("res://scenes/merge_burst_effect.tscn")
const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const MergePhysicsDataClass = preload("res://scripts/merge_physics_data.gd")
const DangerLineClass = preload("res://scripts/danger_line.gd")
const NextPreviewPanelClass = preload("res://scripts/next_preview_panel.gd")
const GimmickObjectScene = preload("res://scenes/gimmick_object.tscn")
const DROP_HEIGHT_RATIO := 0.1655
const DANGER_LINE_REVEAL_FILL_RATIO := 0.8
const GUIDE_BOTTOM_MARGIN := 21.0
const COMBO_SETTLE_MSEC := 500
const COMBO_MAX_WAIT_MSEC := 4000
const MERGE_ATTACK_DELAY := 0.25
const MERGE_PUSH_RADIUS := 260.0
const MERGE_PITCH_SEMITONES_PER_COMBO := 2
const MERGE_PITCH_MAX_SEMITONES := 12
const TRAPDOOR_WALL_PATHS: Array[NodePath] = [^"LeftWallShape", ^"RightWallShape"]

@onready var balls: Node2D = $Balls
@onready var preview_holder: Node2D = $PreviewHolder
@onready var next_panel: NextPreviewPanelClass = $NextPanel
@onready var guide_line: Line2D = $GuideLine
@onready var danger_line: DangerLineClass = $DropLine
@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $DropTimerLabel
@onready var combo_label: Label = $ComboLabel
@onready var autoplay_bot = $MergeAutoplayBot
@onready var merge_hit_stop = $MergeHitStop
@onready var merge_sfx: AudioStreamPlayer = $MergeSfx
@onready var landing_sfx: AudioStreamPlayer = $LandingSfx
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var floor_body: StaticBody2D = $Floor
@onready var left_wall_shape: CollisionShape2D = $LeftWall/CollisionShape2D
@onready var right_wall_shape: CollisionShape2D = $RightWall/CollisionShape2D
@onready var floor_shape: CollisionShape2D = $Floor/CollisionShape2D
@onready var trapdoor_floor: Node2D = $TrapdoorFloor
@onready var trapdoor_segments: Array[StaticBody2D] = [
	$TrapdoorFloor/Left,
	$TrapdoorFloor/Center,
	$TrapdoorFloor/Right,
]
@onready var gimmick_objects: Node2D = $GimmickObjects
@onready var gimmick_overlay: GimmickOverlay = $GimmickOverlay
@export var physics_data: MergePhysicsDataClass
@export_category("Danger / Overflow")
@export_range(0.05, 0.50, 0.005) var danger_line_height_ratio := 0.10
@export_range(10.0, 300.0, 5.0) var warning_distance := 90.0
@export_range(0.5, 10.0, 0.1) var danger_duration := 3.0
@export_range(1, 100, 1) var overflow_damage := 10
var current_level := 0
var next_level := 0
var fixed_drop_level_index := -1
var drop_position_locked := false
var score := 0
var can_drop := true
var is_aiming := false
var aim_x := 360.0
var preview_ball
var danger_timer := 0.0
var danger_state := DangerLineClass.State.SAFE
var is_game_over := false
var input_locked := false
var drop_time_limit := 5.0
var drop_time_remaining := 5.0
var auto_drop_enabled := true
var max_level_index: int = BallCatalogClass.get_max_level_index()
var physics_speed_multiplier := 1.0
var merge_push_force := 90.0
var chain_merge_delay := 0.1
var drop_sequence_active := false
var drop_sequence_id := 0
var combo_count := 0
var combo_points := 0
var last_merge_msec := 0
var combo_effect_tween: Tween
var queued_levels: Array[int] = []
var next_merge_resolution_msec := 0
var dropped_ball_has_landed := false
var external_merge_window_active := false
var external_merge_combo_count := 0
var external_merge_token_serial := 0
var active_external_merge_token := 0
var external_merge_sfx_pitch_scale := 1.0
var external_merge_effect_color := Color.TRANSPARENT
var external_merge_effect_scale := 1.0
var board_inner_left := 96.0
var board_inner_right := 624.0
var board_inner_top := 0.0
var board_inner_bottom := 846.0
var drop_position_y := 140.0
var danger_line_y := 230.0
var danger_suppression_remaining := 0.0
var sealed_stage_index := -1
var blocked_drop_zone := Rect2()
var board_tilt_active := false
var _base_left_wall_transform: Transform2D
var _base_right_wall_transform: Transform2D
var _base_floor_transform: Transform2D
var _base_board_bounds := Rect2()
var trapdoor_enabled := false
var active_gimmick_tweens: Array[Tween] = []

func _ready() -> void:
	background_music.stream.set("loop", true)
	background_music.play()
	_sync_board_geometry_from_collisions()
	_base_left_wall_transform = left_wall.transform
	_base_right_wall_transform = right_wall.transform
	_base_floor_transform = floor_body.transform
	_base_board_bounds = get_board_inner_bounds()
	_apply_physics_data()
	autoplay_bot.set_enabled(OS.is_debug_build() and GameSession.developer_autoplay_enabled)
	_reset_ball_queue()


func _sync_board_geometry_from_collisions() -> void:
	var left_rect := _collision_rect_in_local_space(left_wall_shape)
	var right_rect := _collision_rect_in_local_space(right_wall_shape)
	var floor_rect := _collision_rect_in_local_space(floor_shape)

	board_inner_left = left_rect.end.x
	board_inner_right = right_rect.position.x
	board_inner_top = maxf(left_rect.position.y, right_rect.position.y)
	board_inner_bottom = floor_rect.position.y

	if board_inner_right <= board_inner_left or board_inner_bottom <= board_inner_top:
		push_error("Drop-zone collision shapes do not form a valid play area.")
		return

	var board_height := board_inner_bottom - board_inner_top
	drop_position_y = board_inner_top + board_height * DROP_HEIGHT_RATIO
	# The gameplay board begins where player balls enter the board, not at the
	# hidden top of the tall side-wall collision. Danger and vertical mechanics
	# use this drop-to-floor span as their shared reference.
	var playable_height := board_inner_bottom - drop_position_y
	danger_line_y = drop_position_y + playable_height * danger_line_height_ratio
	aim_x = (board_inner_left + board_inner_right) * 0.5
	danger_line.configure(board_inner_left, board_inner_right, danger_line_y)
	_update_preview_position()


func _collision_rect_in_local_space(collision: CollisionShape2D) -> Rect2:
	if not collision.shape is RectangleShape2D:
		push_error("Drop-zone collision shape must be RectangleShape2D: %s" % collision.get_path())
		return Rect2()
	var rectangle := collision.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	var relative_transform := global_transform.affine_inverse() * collision.global_transform
	var corners := [
		relative_transform * Vector2(-half_size.x, -half_size.y),
		relative_transform * Vector2(half_size.x, -half_size.y),
		relative_transform * Vector2(half_size.x, half_size.y),
		relative_transform * Vector2(-half_size.x, half_size.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _apply_physics_data() -> void:
	if physics_data == null:
		return
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = physics_data.wall_friction
	wall_material.bounce = physics_data.wall_bounce
	wall_material.rough = true
	left_wall.physics_material_override = wall_material
	right_wall.physics_material_override = wall_material
	var floor_material := PhysicsMaterial.new()
	floor_material.friction = physics_data.floor_friction
	floor_material.bounce = physics_data.floor_bounce
	floor_material.rough = true
	floor_body.physics_material_override = floor_material

func can_accept_autoplay_drop() -> bool:
	return can_drop and not input_locked and not is_game_over

func autoplay_drop_at(x_position: float) -> void:
	if can_accept_autoplay_drop():
		aim_x = _clamp_aim_x(x_position)
		_update_preview_position()
		_drop_ball(aim_x)

func get_active_balls() -> Array:
	return balls.get_children()


func spawn_gimmick_ball(
	level_index: int,
	at: Vector2,
	velocity := Vector2.ZERO,
	external_merge_token := 0
) -> MergeBall:
	var ball := _spawn_ball(at, clampi(level_index, 0, max_level_index)) as MergeBall
	if is_instance_valid(ball):
		ball.linear_velocity = velocity
		ball.set_external_merge_token(external_merge_token)
	return ball


func begin_external_merge_window() -> int:
	external_merge_token_serial += 1
	active_external_merge_token = external_merge_token_serial
	external_merge_window_active = true
	external_merge_combo_count = 0
	last_merge_msec = Time.get_ticks_msec()
	return active_external_merge_token


func end_external_merge_window() -> void:
	external_merge_window_active = false
	external_merge_combo_count = 0
	active_external_merge_token = 0


func is_external_merge_window_active() -> bool:
	return external_merge_window_active


func set_external_merge_feedback(pitch_scale: float, effect_color: Color, effect_scale: float) -> void:
	external_merge_sfx_pitch_scale = clampf(pitch_scale, 0.25, 2.0)
	external_merge_effect_color = effect_color
	external_merge_effect_scale = clampf(effect_scale, 1.0, 2.0)


func clear_external_merge_feedback() -> void:
	external_merge_sfx_pitch_scale = 1.0
	external_merge_effect_color = Color.TRANSPARENT
	external_merge_effect_scale = 1.0


func remove_gimmick_ball(ball: MergeBall) -> void:
	if not is_instance_valid(ball) or ball.merge_locked:
		return
	ball.lock_for_merge()
	ball.queue_free()


func replace_ball_stage(ball: MergeBall, new_level_index: int) -> MergeBall:
	if not is_instance_valid(ball) or ball.merge_locked:
		return null
	var at := ball.position
	var velocity := ball.linear_velocity
	remove_gimmick_ball(ball)
	return spawn_gimmick_ball(new_level_index, at, velocity)


func spawn_gimmick_object() -> GimmickObject:
	var object := GimmickObjectScene.instantiate() as GimmickObject
	gimmick_objects.add_child(object)
	return object


func spawn_one_way_platform(rect: Rect2, one_way_margin := 12.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "StageFilterPlatform"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = rect.get_center()
	body.add_to_group(&"drop_landing_surface")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = true
	collision.one_way_collision_margin = one_way_margin
	body.add_child(collision)
	gimmick_objects.add_child(body)
	return body

func get_current_ball_level() -> int:
	return current_level


func get_drop_guide_global_x() -> float:
	return to_global(Vector2(aim_x, drop_position_y)).x


func set_fixed_drop_level(level_index: int) -> void:
	fixed_drop_level_index = clampi(level_index, -1, max_level_index)
	_reset_ball_queue()


func set_drop_position_locked(locked: bool) -> void:
	drop_position_locked = locked
	if locked:
		aim_x = (board_inner_left + board_inner_right) * 0.5
	_update_preview_position()


func clear_active_balls() -> void:
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).queue_free()


func prepare_combo_demo_stack() -> void:
	clear_active_balls()
	var center_x: float = (board_inner_left + board_inner_right) * 0.5
	var stage_five_radius: float = BallCatalogClass.get_ball(4).get_radius()
	var next_y: float = board_inner_bottom - stage_five_radius
	for level in range(4, -1, -1):
		var ball: MergeBall = spawn_gimmick_ball(level, Vector2(center_x, next_y))
		if ball != null:
			ball.freeze = true
			ball.sleeping = true
		var current_radius: float = BallCatalogClass.get_ball(level).get_radius()
		var upper_radius: float = BallCatalogClass.get_ball(level - 1).get_radius() if level > 0 else 0.0
		next_y -= current_radius + upper_radius + 14.0


func get_board_inner_bounds() -> Rect2:
	return Rect2(
		Vector2(board_inner_left, board_inner_top),
		Vector2(board_inner_right - board_inner_left, board_inner_bottom - board_inner_top)
	)


func get_base_board_bounds() -> Rect2:
	return _base_board_bounds


func get_playable_board_bounds() -> Rect2:
	return Rect2(
		Vector2(board_inner_left, drop_position_y),
		Vector2(board_inner_right - board_inner_left, maxf(0.0, board_inner_bottom - drop_position_y))
	)


func suppress_danger_line(seconds: float) -> void:
	danger_suppression_remaining = maxf(danger_suppression_remaining, seconds)


func set_sealed_stage(stage_number: int) -> void:
	sealed_stage_index = stage_number - 1 if stage_number > 0 else -1
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).set_sealed_visual(sealed_stage_index >= 0 and child.merge_level == sealed_stage_index)
	if sealed_stage_index < 0:
		call_deferred("_rescan_touching_merges")


func set_blocked_drop_zone(rect: Rect2) -> void:
	blocked_drop_zone = rect
	aim_x = _clamp_aim_x(aim_x)
	_update_preview_position()


func clear_blocked_drop_zone() -> void:
	blocked_drop_zone = Rect2()


func get_future_levels(count: int) -> Array[int]:
	_ensure_future_queue(count)
	var result: Array[int] = [next_level]
	for index in mini(count - 1, queued_levels.size()):
		result.append(queued_levels[index])
	return result


func reverse_future_queue(count := 3) -> Array[int]:
	var future := get_future_levels(count)
	future.reverse()
	next_level = future[0]
	for index in range(1, future.size()):
		if index - 1 < queued_levels.size():
			queued_levels[index - 1] = future[index]
		else:
			queued_levels.append(future[index])
	_refresh_preview()
	return future


func _ensure_future_queue(count: int) -> void:
	while queued_levels.size() < maxi(0, count - 1):
		queued_levels.append(_random_drop_level())


func apply_velocity_impulse(delta_velocity: Vector2) -> void:
	for child in balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked:
			continue
		ball.apply_central_impulse(delta_velocity * ball.mass)


func set_base_floor_collision_enabled(enabled: bool) -> void:
	floor_shape.disabled = not enabled


func set_ball_vertical_floor_bounds_enabled(enabled: bool) -> void:
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).vertical_floor_bound_enabled = enabled


func set_trapdoor_enabled(enabled: bool) -> void:
	trapdoor_enabled = enabled
	floor_shape.disabled = enabled
	trapdoor_floor.visible = enabled
	var bounds := get_base_board_bounds()
	var segment_width := bounds.size.x / 3.0
	for index in trapdoor_segments.size():
		var segment := trapdoor_segments[index]
		segment.position = Vector2(bounds.position.x + segment_width * (float(index) + 0.5), bounds.end.y)
		var floor_collision := segment.get_node("FloorShape") as CollisionShape2D
		floor_collision.shape = floor_collision.shape.duplicate()
		var floor_rectangle := floor_collision.shape as RectangleShape2D
		floor_rectangle.size = Vector2(segment_width + 2.0, 8.0)
		floor_collision.disabled = not enabled
		for wall_path: NodePath in TRAPDOOR_WALL_PATHS:
			var wall := segment.get_node(wall_path) as CollisionShape2D
			wall.shape = wall.shape.duplicate()
			wall.position.x = (-segment_width * 0.5 if wall_path == TRAPDOOR_WALL_PATHS[0] else segment_width * 0.5)
			wall.disabled = true
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).vertical_floor_bound_enabled = not enabled


func animate_trapdoor(section: int, depth_ratio: float, duration: float, lowered: bool) -> void:
	if not trapdoor_enabled:
		set_trapdoor_enabled(true)
	var target := trapdoor_segments[clampi(section, 0, trapdoor_segments.size() - 1)]
	var base_y := get_base_board_bounds().end.y
	var target_y := base_y + get_base_board_bounds().size.y * depth_ratio if lowered else base_y
	for wall_path: NodePath in TRAPDOOR_WALL_PATHS:
		var wall := target.get_node(wall_path) as CollisionShape2D
		if lowered:
			var rectangle := wall.shape as RectangleShape2D
			rectangle.size.y = get_base_board_bounds().size.y * depth_ratio + 12.0
			wall.position.y = -get_base_board_bounds().size.y * depth_ratio * 0.5
			wall.disabled = true
	suppress_danger_line(duration + 0.5)
	var tween := _create_board_gimmick_tween()
	tween.tween_property(target, "position:y", target_y, duration)
	await tween.finished
	for wall_path: NodePath in TRAPDOOR_WALL_PATHS:
		(target.get_node(wall_path) as CollisionShape2D).disabled = not lowered


func is_ball_position_safe(ball: MergeBall, position: Vector2) -> bool:
	for child in balls.get_children():
		if not child is MergeBall or child == ball:
			continue
		var other := child as MergeBall
		if other.merge_locked:
			continue
		if position.distance_to(other.position) < ball.get_radius() + other.get_radius() + 3.0:
			return false
	return true


func animate_board_compression(step_ratio: float, duration: float) -> void:
	var shift := _base_board_bounds.size.x * step_ratio
	var tween := _create_board_gimmick_tween().set_parallel(true)
	tween.tween_property(left_wall, "position:x", left_wall.position.x + shift, duration)
	tween.tween_property(right_wall, "position:x", right_wall.position.x - shift, duration)
	await tween.finished
	_sync_board_geometry_from_collisions()
	_refresh_ball_bounds()
	suppress_danger_line(0.5)


func animate_floor_rise(step_ratio: float, duration: float) -> void:
	var shift := _base_board_bounds.size.y * step_ratio
	var fixed_danger_y := danger_line_y
	var fixed_drop_y := drop_position_y
	var tween := _create_board_gimmick_tween()
	tween.tween_property(floor_body, "position:y", floor_body.position.y - shift, duration)
	await tween.finished
	_sync_board_geometry_from_collisions()
	danger_line_y = fixed_danger_y
	drop_position_y = fixed_drop_y
	danger_line.configure(board_inner_left, board_inner_right, danger_line_y)
	_update_preview_position()
	_refresh_ball_bounds()
	suppress_danger_line(0.5)


func animate_board_tilt(degrees: float, duration: float) -> void:
	board_tilt_active = not is_zero_approx(degrees)
	var angle := deg_to_rad(degrees)
	var pivot := _base_board_bounds.get_center()
	var targets := [left_wall, right_wall, floor_body]
	var bases := [_base_left_wall_transform, _base_right_wall_transform, _base_floor_transform]
	var tween := _create_board_gimmick_tween().set_parallel(true)
	for index in targets.size():
		var node: Node2D = targets[index]
		var base: Transform2D = bases[index]
		var target_position := pivot + (base.origin - pivot).rotated(angle)
		tween.tween_property(node, "position", target_position, duration)
		tween.tween_property(node, "rotation", base.get_rotation() + angle, duration)
	_set_ball_bounds_enabled(not board_tilt_active)
	await tween.finished
	suppress_danger_line(0.5)


func reset_gimmick_state() -> void:
	end_external_merge_window()
	for tween in active_gimmick_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	active_gimmick_tweens.clear()
	left_wall.transform = _base_left_wall_transform
	right_wall.transform = _base_right_wall_transform
	floor_body.transform = _base_floor_transform
	board_tilt_active = false
	blocked_drop_zone = Rect2()
	sealed_stage_index = -1
	danger_suppression_remaining = 0.0
	for child in gimmick_objects.get_children():
		child.queue_free()
	gimmick_overlay.clear_all()
	set_trapdoor_enabled(false)
	for segment in trapdoor_segments:
		segment.position.y = _base_board_bounds.end.y
	_sync_board_geometry_from_collisions()
	_refresh_ball_bounds()
	for child in balls.get_children():
		if child is MergeBall:
			var ball := child as MergeBall
			ball.set_enlarged(false, 1.0, 0.01)
			ball.set_heavy(false)
			ball.set_hazard_turns(0)
			ball.set_sealed_visual(false)
			ball.set_submerged(false)
			ball.set_merge_curse(false)
			ball.set_rewind_turns(0)
			ball.set_split_cast_reserved(false)
			ball.vertical_floor_bound_enabled = true
			if not ball.merge_locked:
				ball.collision_layer = 1
				ball.collision_mask = 1
				ball.freeze = false


func _create_board_gimmick_tween() -> Tween:
	var tween := create_tween()
	active_gimmick_tweens.append(tween)
	return tween


func _set_ball_bounds_enabled(enabled: bool) -> void:
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).horizontal_bounds_enabled = enabled


func _refresh_ball_bounds() -> void:
	var global_left := to_global(Vector2(board_inner_left, 0.0)).x
	var global_right := to_global(Vector2(board_inner_right, 0.0)).x
	var global_bottom := to_global(Vector2(0.0, board_inner_bottom)).y
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).set_play_area_bounds(global_left, global_right, global_bottom)


func _rescan_touching_merges() -> void:
	var active: Array[MergeBall] = []
	for child in balls.get_children():
		if child is MergeBall and not child.merge_locked:
			active.append(child)
	for first_index in active.size():
		for second_index in range(first_index + 1, active.size()):
			var first := active[first_index]
			var second := active[second_index]
			if first.merge_level != second.merge_level:
				continue
			if first.position.distance_to(second.position) <= first.get_radius() + second.get_radius() + 4.0:
				_on_merge_requested(first, second)
				return


func wait_until_board_settled(max_wait_seconds := 4.0) -> void:
	var started := Time.get_ticks_msec()
	while is_inside_tree():
		var quiet := Time.get_ticks_msec() - last_merge_msec >= COMBO_SETTLE_MSEC
		if quiet and not _has_moving_balls():
			return
		if Time.get_ticks_msec() - started >= roundi(max_wait_seconds * 1000.0):
			return
		await get_tree().physics_frame


func consume_ball(ball: MergeBall) -> void:
	if not is_instance_valid(ball) or ball.merge_locked:
		return
	ball.set_ingestion_marked(false)
	ball.lock_for_merge()
	ball.queue_free()


func animate_ball_consumption(ball: MergeBall, target_global_position: Vector2, duration := 0.55) -> bool:
	if not is_instance_valid(ball) or ball.merge_locked:
		return false
	ball.set_ingestion_marked(false)
	ball.lock_for_merge()
	ball.z_index = 200
	var start_position := ball.global_position
	var control_position := (start_position + target_global_position) * 0.5 + Vector2(0.0, -90.0)
	var start_scale := ball.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(weight: float) -> void:
		if is_instance_valid(ball):
			var first_leg := start_position.lerp(control_position, weight)
			var second_leg := control_position.lerp(target_global_position, weight)
			ball.global_position = first_leg.lerp(second_leg, weight)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ball, "scale", start_scale * 0.12, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ball, "rotation", ball.rotation + TAU * 0.8, duration)
	await tween.finished
	if not is_instance_valid(ball):
		return false
	ball.queue_free()
	return true


func return_ingested_ball_to_board(level: int, source_global_position := Vector2.INF) -> MergeBall:
	var safe_level := clampi(level, 0, max_level_index)
	var ball_data = BallCatalogClass.get_ball(safe_level)
	var radius := 26.0
	if ball_data != null:
		radius = maxf(radius, ball_data.get_radius())
	var minimum_x := board_inner_left + radius
	var maximum_x := board_inner_right - radius
	var spawn_x := (minimum_x + maximum_x) * 0.5
	if minimum_x < maximum_x:
		spawn_x = randf_range(minimum_x, maximum_x)
	var landing_position := Vector2(spawn_x, drop_position_y + radius)
	if not source_global_position.is_finite():
		return _spawn_ball(landing_position, safe_level) as MergeBall
	var source_position := to_local(source_global_position)
	var ball := _spawn_ball(source_position, safe_level) as MergeBall
	if not is_instance_valid(ball):
		return null
	ball.merge_locked = true
	ball.freeze = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.z_index = 200
	ball.scale = Vector2.ONE * 0.18
	var control_position := (source_position + landing_position) * 0.5 + Vector2(0.0, -105.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(weight: float) -> void:
		if is_instance_valid(ball):
			var first_leg := source_position.lerp(control_position, weight)
			var second_leg := control_position.lerp(landing_position, weight)
			ball.position = first_leg.lerp(second_leg, weight)
	, 0.0, 1.0, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "rotation", ball.rotation - TAU * 0.7, 0.58)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(ball):
			return
		ball.merge_locked = false
		ball.collision_layer = 1
		ball.collision_mask = 1
		ball.z_index = 0
		ball.freeze = false
		ball.sleeping = false
		ball.linear_velocity = Vector2(0.0, 35.0)
	)
	return ball

func configure(
	time_limit: float,
	max_ball_level: int,
	physics_speed: float = 1.0,
	push_force: float = 90.0,
	hit_stop_time_scale: float = 0.25,
	hit_stop_duration: float = 0.12,
	chain_delay: float = 0.1
) -> void:
	auto_drop_enabled = time_limit >= 0.0
	drop_time_limit = maxf(0.0, time_limit)
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	max_level_index = clampi(max_ball_level - 1, 0, BallCatalogClass.get_max_level_index())
	physics_speed_multiplier = clampf(physics_speed, 0.5, 3.0)
	merge_push_force = maxf(0.0, push_force)
	merge_hit_stop.configure(hit_stop_time_scale, hit_stop_duration)
	chain_merge_delay = maxf(0.0, chain_delay)
	_reset_ball_queue()

func _process(delta: float) -> void:
	if danger_suppression_remaining > 0.0:
		danger_suppression_remaining = maxf(0.0, danger_suppression_remaining - delta)
	if is_game_over:
		return
	if auto_drop_enabled and can_drop and not input_locked:
		drop_time_remaining = maxf(0.0, drop_time_remaining - delta)
		timer_label.text = "자동 낙하 %.1f초" % drop_time_remaining
		if drop_time_remaining <= 0.0:
			_drop_ball(aim_x)
	_update_danger_state(delta)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or is_game_over:
		return
	if event is InputEventMouseMotion:
		_update_aim(event.position)
	elif event is InputEventScreenDrag:
		_update_aim(event.position)
	elif event is InputEventScreenTouch:
		_handle_pointer_button(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_button(event.position, event.pressed)

func _handle_pointer_button(screen_position: Vector2, pressed: bool) -> void:
	var local := to_local(screen_position)
	if pressed:
		if local.y < board_inner_top or local.y > board_inner_bottom or not can_drop:
			return
		is_aiming = true
		_update_aim(screen_position)
		get_viewport().set_input_as_handled()
	elif is_aiming:
		is_aiming = false
		_update_aim(screen_position)
		if can_drop:
			_drop_ball(aim_x)
		get_viewport().set_input_as_handled()

func _update_aim(screen_position: Vector2) -> void:
	if drop_position_locked:
		return
	var local := to_local(screen_position)
	aim_x = _clamp_aim_x(local.x)
	_update_preview_position()


func _clamp_aim_x(x_position: float) -> float:
	var radius := 26.0
	if is_instance_valid(preview_ball):
		radius = preview_ball.get_radius()
	var clamped := clampf(x_position, board_inner_left + radius, board_inner_right - radius)
	if blocked_drop_zone.has_area() and blocked_drop_zone.position.x <= clamped and clamped <= blocked_drop_zone.end.x:
		var left_candidate := blocked_drop_zone.position.x - radius
		var right_candidate := blocked_drop_zone.end.x + radius
		clamped = left_candidate if absf(clamped - left_candidate) <= absf(clamped - right_candidate) else right_candidate
		clamped = clampf(clamped, board_inner_left + radius, board_inner_right - radius)
	return clamped

func _update_preview_position() -> void:
	guide_line.points = PackedVector2Array([
		Vector2(aim_x, drop_position_y),
		Vector2(aim_x, board_inner_bottom - GUIDE_BOTTOM_MARGIN),
	])
	if is_instance_valid(preview_ball):
		preview_ball.position = Vector2(aim_x, drop_position_y)

func _drop_ball(x: float) -> void:
	if input_locked or is_game_over:
		return
	can_drop = false
	_update_drop_preview_visibility()
	is_aiming = false
	drop_sequence_active = true
	dropped_ball_has_landed = false
	drop_sequence_id += 1
	var current_sequence_id := drop_sequence_id
	combo_count = 0
	combo_points = 0
	last_merge_msec = Time.get_ticks_msec()
	next_merge_resolution_msec = last_merge_msec
	_spawn_ball(Vector2(x, drop_position_y), current_level, current_sequence_id)
	ball_dropped.emit()
	_advance_ball_queue()
	_finish_drop_sequence(current_sequence_id)

func _finish_drop_sequence(sequence_id: int) -> void:
	var sequence_started_msec := Time.get_ticks_msec()
	var turn_was_emitted := false
	await get_tree().physics_frame
	while is_inside_tree():
		var now := Time.get_ticks_msec()
		var merge_is_quiet := now - last_merge_msec >= COMBO_SETTLE_MSEC
		var exceeded_max_wait := now - sequence_started_msec >= COMBO_MAX_WAIT_MSEC
		var turn_is_ready: bool = dropped_ball_has_landed and merge_is_quiet
		# 적 턴은 합성/연쇄 합성이 끝난 시점에 넘긴다. 공 전체 정지는 투하 UI 복구에만 사용한다.
		if not turn_was_emitted and (turn_is_ready or exceeded_max_wait):
			turn_was_emitted = true
			turn_completed.emit()
		if (turn_is_ready and not _has_moving_balls()) or exceeded_max_wait:
			break
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	if sequence_id != drop_sequence_id:
		return
	drop_sequence_active = false
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()
	if not turn_was_emitted:
		turn_completed.emit()

func _spawn_ball(at: Vector2, level: int, contact_sequence_id: int = -1):
	if not is_inside_tree() or not is_instance_valid(balls) or balls.is_queued_for_deletion():
		return null
	var ball = BallScene.instantiate()
	ball.position = at
	# CCD가 기본 위치 (0, 0)에서 생성 위치까지의 이동을 벽 관통으로 오인하지 않도록
	# 씬 트리에 추가하기 전에 초기 위치를 지정한다.
	ball.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	balls.add_child(ball)
	ball.setup(level, physics_speed_multiplier)
	ball.set_sealed_visual(sealed_stage_index >= 0 and ball.merge_level == sealed_stage_index)
	if physics_data != null:
		var ball_material := PhysicsMaterial.new()
		ball_material.friction = physics_data.ball_friction
		ball_material.rough = true
		ball.physics_material_override = ball_material
		ball.linear_damp = physics_data.ball_linear_damp
		ball.angular_damp = physics_data.ball_angular_damp
		ball.configure_sleep_assist(
			physics_data.sleep_assist_enabled,
			physics_data.sleep_assist_settle_time,
			physics_data.sleep_assist_max_displacement
		)
		ball.configure_contact_stabilization(
			physics_data.contact_horizontal_damp,
			physics_data.contact_angular_damp,
			physics_data.contact_max_angular_speed
		)
		ball.configure_micro_wake_guard(
			physics_data.micro_wake_guard_enabled,
			physics_data.micro_wake_grace_time,
			physics_data.micro_wake_linear_threshold,
			physics_data.micro_wake_angular_threshold
		)
	_enable_ball_ccd_after_spawn(ball)
	var global_left := to_global(Vector2(board_inner_left, 0.0)).x
	var global_right := to_global(Vector2(board_inner_right, 0.0)).x
	var global_bottom := to_global(Vector2(0.0, board_inner_bottom)).y
	ball.set_play_area_bounds(global_left, global_right, global_bottom)
	if board_tilt_active:
		ball.horizontal_bounds_enabled = false
	ball.merge_requested.connect(_on_merge_requested)
	if contact_sequence_id >= 0:
		ball.first_contact.connect(_on_dropped_ball_first_contact.bind(contact_sequence_id, at.x), CONNECT_ONE_SHOT)
	return ball


func _enable_ball_ccd_after_spawn(ball: RigidBody2D) -> void:
	await get_tree().physics_frame
	if is_instance_valid(ball) and not ball.merge_locked:
		ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE


func _on_dropped_ball_first_contact(_ball: MergeBall, sequence_id: int, original_drop_x: float) -> void:
	if sequence_id != drop_sequence_id or is_game_over:
		return
	dropped_ball_has_landed = true
	landing_sfx.play()
	player_ball_landed.emit(_ball.merge_level, original_drop_x)
	if not input_locked:
		can_drop = true
	if auto_drop_enabled:
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()

func _advance_ball_queue() -> void:
	current_level = next_level
	next_level = queued_levels.pop_front() if not queued_levels.is_empty() else _random_drop_level()
	_refresh_preview()

func _reset_ball_queue() -> void:
	current_level = _random_drop_level()
	next_level = _random_drop_level()
	queued_levels.clear()
	_ensure_future_queue(3)
	drop_time_remaining = drop_time_limit
	timer_label.visible = auto_drop_enabled
	_refresh_preview()

func _random_drop_level() -> int:
	if fixed_drop_level_index >= 0:
		return fixed_drop_level_index
	return randi_range(0, mini(4, max_level_index))

func _refresh_preview() -> void:
	if is_instance_valid(preview_ball):
		preview_ball.queue_free()
	preview_ball = BallScene.instantiate()
	preview_holder.add_child(preview_ball)
	preview_ball.position = Vector2(aim_x, drop_position_y)
	preview_ball.setup(current_level, physics_speed_multiplier)
	preview_ball.lock_for_merge()
	next_panel.set_preview_data(BallCatalogClass.get_ball(next_level))

func _on_merge_requested(first, second) -> void:
	if (
		first.merge_locked
		or second.merge_locked
		or first.ice_cast_reserved
		or second.ice_cast_reserved
		or first.split_cast_reserved
		or second.split_cast_reserved
		or first.merge_level >= max_level_index
	):
		return
	if sealed_stage_index >= 0 and first.merge_level == sealed_stage_index:
		return
	var at: Vector2 = (first.position + second.position) * 0.5
	var level: int = first.merge_level + 1
	var carries_ingestion_target: bool = first.ingestion_marked or second.ingestion_marked
	var ice_target_count := int(first.ice_targeted) + int(second.ice_targeted)
	var involved_cursed: bool = first.is_merge_cursed or second.is_merge_cursed
	var involved_damage_background: bool = (
		first.damage_background_marked or second.damage_background_marked
	)
	var source_ids: Array[int] = [first.get_instance_id(), second.get_instance_id()]
	# 합성 충돌이 발생한 투하 턴을 고정한다. 이후 지연 연쇄 처리 중 다음 투하가
	# 시작되어도 이 공격의 소속 턴은 바뀌지 않는다.
	var attack_drop_sequence_id := drop_sequence_id
	var result_external_merge_token := 0
	if external_merge_window_active and active_external_merge_token > 0:
		if (
			first.external_merge_token == active_external_merge_token
			or second.external_merge_token == active_external_merge_token
		):
			result_external_merge_token = active_external_merge_token
	# A damage-background ball remains hazardous after its original external
	# window closes. Its next merge is enemy-owned once, but the merged result
	# is deliberately normal so the hazard cannot propagate through a chain.
	var is_external_merge := result_external_merge_token > 0 or involved_damage_background
	if involved_damage_background:
		result_external_merge_token = 0
	first.lock_for_merge()
	second.lock_for_merge()
	# 연쇄 접촉은 순서를 예약해 하나씩 보여준 뒤 합성한다. 실제 시간 기준이라 FPS와 무관하다.
	if not is_external_merge and drop_sequence_active and chain_merge_delay > 0.0:
		var now_msec := Time.get_ticks_msec()
		var scheduled_msec := now_msec
		if combo_count > 0:
			scheduled_msec = maxi(now_msec, next_merge_resolution_msec)
		next_merge_resolution_msec = scheduled_msec + roundi(chain_merge_delay * 1000.0)
		var wait_seconds := float(scheduled_msec - now_msec) / 1000.0
		if wait_seconds > 0.0:
			await get_tree().create_timer(wait_seconds, true, false, true).timeout
		if not is_inside_tree() or not is_instance_valid(first) or not is_instance_valid(second):
			return
	merge_hit_stop.play()
	first.queue_free()
	second.queue_free()
	var merged_ball_data: Resource = BallCatalogClass.get_ball(level)
	var earned_points: int = merged_ball_data.merge_score
	var attack_combo_count := 1
	if is_external_merge:
		external_merge_combo_count += 1
		attack_combo_count = external_merge_combo_count
		last_merge_msec = Time.get_ticks_msec()
	else:
		score += earned_points
		score_label.text = "점수 %d" % score
	if not is_external_merge and drop_sequence_active:
		combo_count += 1
		combo_points += earned_points
		last_merge_msec = Time.get_ticks_msec()
		attack_combo_count = combo_count
	if not is_external_merge:
		player_merge_registered.emit(earned_points, level)
	merge_registered.emit(level, at, attack_combo_count, source_ids, involved_cursed)
	_spawn_merge_burst(at, merged_ball_data, attack_combo_count, is_external_merge)
	var merge_damage := _calculate_merge_damage(earned_points, attack_combo_count)
	if not is_external_merge and attack_combo_count >= 2:
		_show_combo_effect(attack_combo_count, merge_damage)
	if is_external_merge:
		external_merge_damage_requested.emit(merge_damage, attack_combo_count, earned_points, at, level)
	else:
		_emit_merge_attack_after_delay(
			merge_damage,
			attack_combo_count,
			earned_points,
			at,
			level,
			attack_drop_sequence_id
		)
	print("[MERGE] %d단계 + %d단계 -> %d단계 | 획득=%d | 소유=%s | 콤보=%d | 누적=%d" % [
		level, level, level + 1, earned_points,
		"EXTERNAL" if is_external_merge else "PLAYER", attack_combo_count, combo_points
	])
	call_deferred(
		"_spawn_merged_ball",
		at,
		level,
		carries_ingestion_target,
		ice_target_count,
		source_ids,
		attack_combo_count,
		result_external_merge_token,
		is_external_merge
	)


func _spawn_merge_burst(at: Vector2, data: Resource, merge_combo_count: int, is_external_merge := false) -> void:
	var burst = MergeBurstEffectScene.instantiate()
	add_child(burst)
	var burst_color: Color = data.glow_color
	var burst_scale := 1.0
	if is_external_merge:
		if external_merge_effect_color.a > 0.0:
			burst_color = external_merge_effect_color
		burst_scale = external_merge_effect_scale
	burst.play(at, burst_color, data.get_radius(), merge_combo_count, data.level, burst_scale)


func _spawn_merged_ball(
	at: Vector2,
	level: int,
	carries_ingestion_target: bool = false,
	ice_target_count: int = 0,
	source_ids: Array[int] = [],
	merge_combo_count: int = 1,
	external_merge_token: int = 0,
	is_external_merge := false
) -> void:
	var merged_ball = _spawn_ball(at, level)
	if is_instance_valid(merged_ball):
		merged_ball.set_external_merge_token(external_merge_token)
	if carries_ingestion_target and is_instance_valid(merged_ball):
		merged_ball.set_ingestion_marked(true)
		ingestion_target_replaced.emit(merged_ball)
	if ice_target_count > 0 and is_instance_valid(merged_ball):
		ice_telegraph_merge_resolved.emit(merged_ball, source_ids, ice_target_count)
	if is_instance_valid(merged_ball):
		_play_merge_sfx(
			merge_combo_count,
			external_merge_sfx_pitch_scale if is_external_merge else 1.0
		)
		merge_completed.emit(merged_ball)
	if not is_instance_valid(merged_ball) or merge_push_force <= 0.0:
		return
	_apply_merge_push(at, merged_ball)


func _play_merge_sfx(merge_combo_count: int, pitch_multiplier := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = merge_sfx.stream
	player.volume_db = merge_sfx.volume_db
	var semitones := mini(
		maxi(merge_combo_count - 1, 0) * MERGE_PITCH_SEMITONES_PER_COMBO,
		MERGE_PITCH_MAX_SEMITONES
	)
	player.pitch_scale = maxf(0.25, pitch_multiplier) * pow(2.0, float(semitones) / 12.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	# The 1.104 s source waveform stays flat until about 0.176 s. Keep a
	# few milliseconds of lead-in so the first transient is not clipped.
	player.play(0.17)


func _apply_merge_push(origin: Vector2, merged_ball: MergeBall) -> void:
	for child in balls.get_children():
		if not child is MergeBall or child == merged_ball:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or ball.is_queued_for_deletion():
			continue
		var offset := ball.position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance >= MERGE_PUSH_RADIUS:
			continue
		var falloff := 1.0 - distance / MERGE_PUSH_RADIUS
		var impulse := offset.normalized() * merge_push_force * falloff * ball.mass
		ball.apply_central_impulse(impulse)

func _update_danger_state(delta: float) -> void:
	if danger_suppression_remaining > 0.0:
		_refresh_danger_visuals([])
		return
	var overflow_balls := _get_overflow_balls()
	if not overflow_balls.is_empty():
		if danger_state != DangerLineClass.State.DANGER:
			danger_state = DangerLineClass.State.DANGER
			danger_timer = danger_duration
		_refresh_danger_visuals(overflow_balls)
		if not input_locked:
			danger_timer = maxf(0.0, danger_timer - delta)
		if danger_timer <= 0.0:
			var confirmed_balls := _get_overflow_balls()
			if not confirmed_balls.is_empty():
				_resolve_overflow(confirmed_balls)
			else:
				_resolve_danger_recovery()
		return
	if danger_state == DangerLineClass.State.DANGER:
		_resolve_danger_recovery()
	else:
		danger_state = DangerLineClass.State.WARNING if _has_warning_ball() else DangerLineClass.State.SAFE
		_refresh_danger_visuals([])


func _get_overflow_balls() -> Array[MergeBall]:
	var result: Array[MergeBall] = []
	for child in balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or not ball.has_landed():
			continue
		if ball.position.y < danger_line_y:
			result.append(ball)
	return result


func _has_warning_ball() -> bool:
	for child in balls.get_children():
		if not child is MergeBall:
			continue
		var ball := child as MergeBall
		if ball.merge_locked or not ball.has_landed():
			continue
		if ball.position.y <= danger_line_y + warning_distance:
			return true
	return false


func _resolve_danger_recovery() -> void:
	danger_timer = 0.0
	danger_state = DangerLineClass.State.WARNING if _has_warning_ball() else DangerLineClass.State.SAFE
	_refresh_danger_visuals([])


func _resolve_overflow(overflow_balls: Array[MergeBall]) -> void:
	for ball in overflow_balls:
		remove_gimmick_ball(ball)
	danger_timer = 0.0
	danger_state = DangerLineClass.State.WARNING if _has_warning_ball() else DangerLineClass.State.SAFE
	_refresh_danger_visuals([])
	overflow_triggered.emit(overflow_damage)


func _refresh_danger_visuals(overflow_balls: Array[MergeBall]) -> void:
	for child in balls.get_children():
		if child is MergeBall:
			(child as MergeBall).set_danger_marked(child in overflow_balls)
	danger_line.set_state(danger_state)
	danger_line.visible = danger_state != DangerLineClass.State.SAFE and danger_suppression_remaining <= 0.0

func _has_moving_balls() -> bool:
	for child in balls.get_children():
		if child.merge_locked:
			continue
		if not child.sleeping and (child.linear_velocity.length() > 8.0 or absf(child.angular_velocity) > 0.2):
			return true
	return false

func _trigger_game_over() -> void:
	is_game_over = true
	can_drop = false
	_update_drop_preview_visibility()
	next_panel.visible = false
	game_over.emit()

func set_input_enabled(enabled: bool) -> void:
	input_locked = not enabled
	is_aiming = false
	next_panel.visible = not is_game_over
	if enabled and (dropped_ball_has_landed or not drop_sequence_active) and not is_game_over:
		can_drop = true
		drop_time_remaining = drop_time_limit
	_update_drop_preview_visibility()

func _update_drop_preview_visibility() -> void:
	var should_show := can_drop and not is_game_over
	guide_line.visible = should_show
	preview_holder.visible = should_show

func _calculate_merge_damage(base_points: int, count: int) -> int:
	var multiplier := minf(2.0, 1.0 + 0.25 * float(count - 1))
	return roundi(float(base_points) * multiplier)

func _emit_merge_attack_after_delay(
	damage: int,
	count: int,
	base_points: int,
	origin: Vector2,
	ball_level: int,
	attack_drop_sequence_id: int
) -> void:
	await get_tree().create_timer(MERGE_ATTACK_DELAY).timeout
	if not is_inside_tree():
		return
	print("[MERGE ATTACK REQUEST] 콤보=%d | 기본=%d | 피해=%d" % [count, base_points, damage])
	merge_attack_requested.emit(
		damage,
		count,
		base_points,
		to_global(origin),
		ball_level,
		attack_drop_sequence_id
	)

func _show_combo_effect(count: int, damage: int) -> void:
	if combo_effect_tween != null and combo_effect_tween.is_valid():
		combo_effect_tween.kill()
	combo_label.text = "COMBO x%d\nDAMAGE %d" % [count, damage]
	combo_label.visible = true
	combo_label.scale = Vector2(0.6, 0.6)
	combo_label.modulate = Color(1, 1, 1, 0)
	combo_effect_tween = create_tween()
	combo_effect_tween.set_parallel(true)
	combo_effect_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combo_effect_tween.tween_property(combo_label, "modulate", Color.WHITE, 0.15)
	combo_effect_tween.set_parallel(false)
	combo_effect_tween.tween_interval(0.35)
	combo_effect_tween.tween_property(combo_label, "modulate:a", 0.0, 0.22)
	combo_effect_tween.tween_callback(func(): combo_label.visible = false)
