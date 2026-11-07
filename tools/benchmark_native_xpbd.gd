extends RefCounted
## Scoped same-fixture CPU timing. No rendering-frame/FPS claim.
const XP = preload("res://scripts/gimmicks/visuals/soft_pond_layer.gd")
const NP = preload("res://scripts/gimmicks/visuals/native_xpbd_pond_layer.gd")

func run(tree: SceneTree, count := 48, ticks := 120) -> Array:
	var game = tree.current_scene.get_node("MergeGame")
	var settings = load("res://resources/native_xpbd_pond_physics.tres")
	for node in tree.current_scene.find_children("*", "Node2D", true, false):
		if node.get_script() == XP or node.get_script() == NP:
			node.restore_balls()
	for ball in game.get_active_balls(): ball.free()
	var results: Array = []
	# Alternate order, rebuild identical initial conditions for every run.
	for kind in [XP, NP, NP, XP]:
		var layer = kind.new()
		tree.current_scene.add_child(layer)
		layer.configure(game, settings)
		layer.set_physics_process(false)
		var balls: Array = []
		for index in count:
			var row := index / 6
			var col := index % 6
			var ball = game.spawn_gimmick_ball((row+col)%4, Vector2(game.board_inner_left+45+col*78, game.drop_position_y+45+row*70), Vector2.ZERO)
			ball.rotation = 0.0
			ball.angular_velocity = 0.0
			ball.gravity_scale = -1.0
			ball.constant_force = Vector2.ZERO
			for c in ball.merge_requested.get_connections(): ball.merge_requested.disconnect(c.callable)
			layer._register(ball)
			balls.append(ball)
		for tick in 30: layer._physics_process(1.0/60.0)
		var elapsed: Array[float] = []
		for tick in ticks:
			var start := Time.get_ticks_usec()
			layer._physics_process(1.0/60.0)
			elapsed.append((Time.get_ticks_usec()-start)/1000.0)
		var average := 0.0
		for value in elapsed: average += value/elapsed.size()
		elapsed.sort()
		results.append({"backend":"XPBDNative" if kind == NP else "XPBD", "balls":count, "ticks":ticks, "mean_ms":average, "median_ms":elapsed[elapsed.size()/2], "p95_ms":elapsed[int(elapsed.size()*0.95)], "sleeping":layer.sleeping})
		layer.restore_balls()
		layer.free()
		for ball in balls: ball.free()
	return results
