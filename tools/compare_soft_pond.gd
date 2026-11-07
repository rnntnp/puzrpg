extends RefCounted
## Scoped deterministic solver comparison. Invoke run() from the stage-60 MCP
## scene; each fixture starts from the same outline, poses and velocities.
## XPBD uses six controls; standard Quark uses its configured particle count.
const XP = preload("res://scripts/gimmicks/visuals/soft_pond_layer.gd")
const QP = preload("res://scripts/gimmicks/visuals/quark_pond_layer.gd")
const NP = preload("res://scripts/gimmicks/visuals/native_xpbd_pond_layer.gd")

func run(tree: SceneTree, candidates: Array, names: Array = []) -> Array:
	var game = tree.current_scene.get_node("MergeGame")
	var existing = tree.current_scene.find_children("*", "Node2D", true, false).filter(func(n): return n.get_script() == QP or n.get_script() == XP or n.get_script() == NP)
	var settings = existing[0].tuning.duplicate()
	for layer in existing:
		layer.restore_balls()
	for ball in game.get_active_balls(): ball.free()
	var scenarios = ["ceiling_small", "ceiling_slow", "ceiling_angle", "ceiling_large", "pair_head", "pair_angle", "pair_large", "stack_hit", "floor_small", "free_shape"]
	var results: Array = []
	for candidate in candidates:
		var config = settings.duplicate()
		for key in candidate:
			if key != "name" and key != "backend": config.set(key, candidate[key])
		for scenario in scenarios:
			if not names.is_empty() and not scenario in names: continue
			results.append(_fixture(tree, game, config, candidate, scenario))
	return results

func _fixture(tree: SceneTree, game: Node2D, config: Resource, candidate: Dictionary, scenario: String) -> Dictionary:
	var backend: String = candidate.get("backend", "QuarkPhysics")
	var native: bool = backend == "QuarkPhysics"
	var layer = (QP if native else (NP if backend == "XPBDNative" else XP)).new()
	tree.current_scene.add_child(layer)
	layer.configure(game, config)
	layer.set_physics_process(false)
	var cx: float = (game.board_inner_left + game.board_inner_right) * 0.5
	var top: float = game.drop_position_y
	var cy: float = (top + game.board_inner_bottom) * 0.5
	var balls: Array = []
	if scenario.begins_with("ceiling"):
		var level = 7 if scenario == "ceiling_large" else 0
		var velocity = Vector2(0, -400 if scenario == "ceiling_slow" else -900)
		if scenario == "ceiling_angle": velocity.x = 300
		balls.append(_spawn(game, layer, level, Vector2(cx, top + 240), velocity, -1.0))
	elif scenario == "floor_small":
		balls.append(_spawn(game, layer, 0, Vector2(cx, game.board_inner_bottom - 240), Vector2(0, 900), 1.0))
	elif scenario.begins_with("pair"):
		var large: bool = scenario == "pair_large"
		balls.append(_spawn(game, layer, 5 if large else 0, Vector2(cx - 130, cy + (22 if scenario == "pair_angle" else 0)), Vector2(250, 0), 0.0))
		balls.append(_spawn(game, layer, 7 if large else 1, Vector2(cx + 100, cy), Vector2(-120, 0), 0.0))
	elif scenario == "stack_hit":
		var y: float = top
		for level in [6, 3, 1]:
			var ball = _spawn(game, layer, level, Vector2(cx, cy), Vector2.ZERO, -1.0)
			var radius: float = ball.get_radius()
			var s: Dictionary = layer.states[ball.get_instance_id()]
			var shift = game.to_global(Vector2(cx,y+radius))-ball.global_position
			for i in s.points.size():
				s.points[i] += shift
				s.previous[i] += shift
				if native:
					s.particles[i].set_global_position(s.points[i])
					s.particles[i].set_previous_global_position(s.points[i])
			ball.global_position += shift
			s.center = ball.global_position
			y += radius*2+2
			balls.append(ball)
		for tick in range(180): layer._physics_process(1.0/60.0)
		balls.append(_spawn(game, layer, 0, Vector2(cx+12,minf(y+160,game.board_inner_bottom-40)), Vector2(0,-700), -1.0))
	else:
		var ball = _spawn(game, layer, 7, Vector2(cx,cy), Vector2.ZERO, 0.0)
		balls.append(ball)
		var s: Dictionary = layer.states[ball.get_instance_id()]
		var center: Vector2 = layer._center(s.points)
		for i in s.points.size():
			s.points[i] = center+(s.points[i]-center)*Vector2(0.92,1.04)
			s.previous[i] = s.points[i]
			if native:
				s.particles[i].set_global_position(s.points[i])
				s.particles[i].set_previous_global_position(s.points[i])
	var trace: Array = []
	var peak_strain := 0.0
	var first_contact := -1
	var max_speed := 0.0
	var quiet_ticks := 0
	var settled_at := -1
	var finite := true
	var tail_internal_square := 0.0
	var tail_samples := 0
	for tick in range(180):
		layer._physics_process(1.0/60.0)
		var frame: Array = []
		var quiet := true
		for ball in balls:
			var s: Dictionary = layer.states[ball.get_instance_id()]
			var velocity: Vector2 = layer._center(s.velocities)
			var strain := 0.0
			for edge in s.edges:
				strain = maxf(strain,absf(s.points[edge.i].distance_to(s.points[edge.j])/edge.length-1.0))
			peak_strain = maxf(peak_strain,strain)
			max_speed = maxf(max_speed,velocity.length())
			var square := 0.0
			for v in s.velocities:
				square += v.length_squared()/s.velocities.size()
				finite = finite and v.is_finite()
				if tick >= 120:
					tail_internal_square += (v-velocity).length_squared()
					tail_samples += 1
			quiet = quiet and square < 144.0 and velocity.length() < 6.0
			if first_contact < 0 and not s.seen.is_empty(): first_contact = tick
			var center: Vector2 = game.to_local(layer._center(s.points))
			frame.append([center.x,center.y,velocity.x,velocity.y,strain])
		quiet_ticks = quiet_ticks+1 if quiet else 0
		if quiet_ticks >= 45 and settled_at < 0: settled_at=tick-44
		if tick % 6 == 0: trace.append(frame)
	var result = {"candidate":candidate.name,"scenario":scenario,"trace":trace,"peak_strain":peak_strain,"max_speed":max_speed,"settled_at":settled_at,"first_contact":first_contact,"finite":finite,"tail_internal_rms":sqrt(tail_internal_square/maxi(tail_samples,1))}
	layer.restore_balls()
	layer.free()
	for ball in balls: ball.free()
	return result

func _spawn(game: Node2D, layer: Node2D, level: int, position: Vector2, velocity: Vector2, gravity: float) -> Node2D:
	var ball = game.spawn_gimmick_ball(level,position,velocity)
	ball.rotation = 0.0
	ball.angular_velocity = 0.0
	ball.gravity_scale = gravity
	ball.constant_force = Vector2.ZERO
	for connection in ball.merge_requested.get_connections(): ball.merge_requested.disconnect(connection.callable)
	layer._register(ball)
	return ball
