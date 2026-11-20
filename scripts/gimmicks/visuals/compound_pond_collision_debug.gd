extends Node2D
## Read-only stage 63 overlay: actual enabled physics shapes, never warp cages.
var game: MergeGame
var tuning: Resource

func configure(board: MergeGame, settings: Resource) -> void:
	game = board
	tuning = settings
	z_as_relative = false
	z_index = 100
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game) or tuning == null or not tuning.show_collision_debug: return
	for ball in game.get_active_balls():
		if ball is MergeBall and not ball.merge_locked and not ball.is_queued_for_deletion():
			_draw_body(ball, tuning.collision_debug_color)
	if is_instance_valid(game.preview_ball) and not game.preview_ball.is_queued_for_deletion():
		_draw_body(game.preview_ball, tuning.collision_debug_preview_color)

func _draw_body(ball: MergeBall, color: Color) -> void:
	for child in ball.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null or child.is_queued_for_deletion(): continue
		var outline := _outline(child.shape)
		if outline.size() < 3: continue
		var to_overlay: Transform2D = global_transform.affine_inverse() * child.global_transform
		for i in outline.size(): outline[i] = to_overlay * outline[i]
		var fill := color
		fill.a *= 0.08
		draw_colored_polygon(outline, fill)
		outline.append(outline[0])
		var canvas_scale := maxf(0.0001, get_global_transform_with_canvas().x.length())
		draw_polyline(outline, color, tuning.collision_debug_line_width / canvas_scale, true)

func _outline(shape: Shape2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	if shape is ConvexPolygonShape2D:
		return shape.points.duplicate()
	if shape is CircleShape2D:
		for i in 64: points.append(Vector2.from_angle(TAU * i / 64.0) * shape.radius)
	elif shape is CapsuleShape2D:
		var stem: float = maxf(0.0, shape.height * 0.5 - shape.radius)
		for i in 33: points.append(Vector2.from_angle(PI + PI * i / 32.0) * shape.radius + Vector2(0.0, -stem))
		for i in 33: points.append(Vector2.from_angle(PI * i / 32.0) * shape.radius + Vector2(0.0, stem))
	elif shape is RectangleShape2D:
		var half: Vector2 = shape.size * 0.5
		points = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	return points
