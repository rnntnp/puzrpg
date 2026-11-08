extends "res://scripts/gimmicks/visuals/soft_pond_layer.gd"
## Same solver lifecycle, force integration, collision queries and gameplay.
## Uses the optional Windows kernel or the GDScript contact solver.
var kernel: RefCounted
var native_wall_planes: Array = []

func _register(ball: MergeBall) -> void:
	super._register(ball)
	var s: Dictionary = states[ball.get_instance_id()]
	var rest_radius := 0.0
	var rest_center := _center(s.rest)
	for p: Vector2 in s.outline_rest:
		rest_radius = maxf(rest_radius, p.distance_to(rest_center))
	# Fixed envelope: original silhouette plus deformation allowance. No outline
	# generation or radius recalculation during broad-phase collision checks.
	s.broad_radius = rest_radius * tuning.broad_phase_radius_scale + 0.05
	# Keep the original six controls, rest lengths and rendered meshes. Only
	# uniformly sample a coarse pair-query/guide polygon, while native contact
	# force distribution uses the original dense support patch.
	var stride: int = tuning.collision_outline_stride
	if stride > 1 and kernel != null:
		# Planar wall contacts retain the full support patch. Coarse endpoints
		# can alternate under steady pressure even with fixed wall normals.
		s.wall_outline_bindings = s.outline_bindings
		s.wall_sectors = s.sectors
		var outline: PackedVector2Array = s.outline_rest
		var count := maxi(6, 2 * (outline.size() / (stride * 2)))
		var lengths := PackedFloat32Array([0.0])
		for i in outline.size():
			lengths.append(lengths[-1] + outline[i].distance_to(outline[(i + 1) % outline.size()]))
		var bindings: Array[Vector4] = []
		for i in count:
			var distance: float = lengths[-1] * i / count
			var edge := 0
			while edge + 1 < outline.size() and lengths[edge + 1] < distance: edge += 1
			var point := outline[edge].lerp(outline[(edge + 1) % outline.size()], (distance - lengths[edge]) / maxf(lengths[edge + 1] - lengths[edge], 0.001))
			bindings.append(_bind_outline(point, s.rest))
		bindings.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
		var sectors: Array[PackedVector2Array] = []
		for i in POINT_COUNT: sectors.append(PackedVector2Array())
		for binding in bindings:
			sectors[int(binding.x)].append(Vector2(binding.z, binding.w))
		s.outline_bindings = bindings
		s.sectors = sectors
		s.surface_dirty = true
		s.query_dirty = true
		_surface(s)
		(s.collider.shape as ConvexPolygonShape2D).points = _query_shape(s).points

func _candidate_pairs(active: Array, dt: float) -> Array:
	var pairs: Array = []
	var grid: Dictionary = {}
	var tested: Dictionary = {}
	var cell_size: float = tuning.broad_phase_cell_size
	for i in active.size():
		var a: Dictionary = active[i]
		a.query_center = _center(a.points)
		var speed: float = a.published_velocity.length()
		a.broad_speed = speed
		var padding := 2.0 + speed * dt
		var extent: Vector2 = Vector2.ONE * (a.broad_radius + padding)
		var first := Vector2i(((a.query_center - extent) / cell_size).floor())
		var last := Vector2i(((a.query_center + extent) / cell_size).floor())
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell): grid[cell] = []
				for j in grid[cell]:
					var key := Vector2i(j, i)
					if tested.has(key): continue
					tested[key] = true
					var b: Dictionary = active[j]
					var reach: float = a.broad_radius + b.broad_radius + 4.0 + (speed + b.broad_speed) * dt
					if (a.query_center as Vector2).distance_squared_to(b.query_center) <= reach * reach:
						pairs.append([b, a])
				grid[cell].append(i)
	return pairs

func configure(board: MergeGame, settings: Resource) -> void:
	super.configure(board, settings)
	if not ClassDB.class_exists("XPBDPondKernel") and OS.has_feature("windows") and OS.has_feature("x86_64"):
		GDExtensionManager.load_extension("res://addons/xpbd_pond/xpbd_pond.gdextension")
	if ClassDB.class_exists("XPBDPondKernel"):
		kernel = ClassDB.instantiate("XPBDPondKernel")
	else:
		push_warning("Native XPBD unavailable; using the GDScript solver.")

func _solve_constraints(active: Array, pairs: Array, dt: float) -> void:
	if kernel == null:
		super._solve_constraints(active, pairs, dt)
		return
	# Board transform can change; sample the same four planes each substep.
	var normals := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]
	var anchors := [Vector2(game.board_inner_left,0),Vector2(game.board_inner_right,0),Vector2(0,game.drop_position_y),Vector2(0,game.board_inner_bottom)]
	var bodies := [game.left_wall,game.right_wall,_ceiling(),game.floor_body]
	native_wall_planes.clear()
	for i in 4:
		var normal: Vector2 = game.global_transform.basis_xform(normals[i]).normalized()
		native_wall_planes.append({"normal":normal,"plane":game.to_global(anchors[i]).dot(normal),"body":bodies[i]})
	kernel.solve_constraints(active, pairs, dt, tuning.solver_iterations, tuning.maximum_compression, tuning.area_compliance, native_wall_planes, manifolds, contacts, self)

func _structure(s: Dictionary, dt: float) -> void:
	if kernel == null:
		super._structure(s, dt)
		return
	kernel.structure(s, dt, POINT_COUNT / s.ball.mass, tuning.maximum_compression, tuning.area_compliance)

func _surface(s: Dictionary) -> PackedVector2Array:
	if kernel == null: return super._surface(s)
	return kernel.surface(s)

func _support(points: PackedVector2Array, axis: Vector2) -> Array[int]:
	if kernel == null: return super._support(points, axis)
	return kernel.support(points, axis)

func _surface_gradient(s: Dictionary, indices: Array[int]) -> PackedFloat32Array:
	if kernel == null: return super._surface_gradient(s, indices)
	return kernel.surface_gradient(s, indices)

func _resolve_contact(a: Dictionary, b: Dictionary, m: Dictionary) -> void:
	if kernel == null:
		_resolve_script_contact(a, b, m)
		return
	if kernel.resolve_contact(a, b, m, POINT_COUNT / a.ball.mass, POINT_COUNT / b.ball.mass):
		contacts[str(a.ball.get_instance_id())+":"+str(b.ball.get_instance_id())] = [a.ball,b.ball,m.normal]

func _resolve_script_contact(a: Dictionary, b: Dictionary, contact: Dictionary) -> void:
	var normal: Vector2 = contact.normal
	var ga: PackedFloat32Array = contact.ga
	var gb: PackedFloat32Array = contact.gb
	var points_a: PackedVector2Array = a.points
	var points_b: PackedVector2Array = b.points
	var position_a := Vector2.ZERO
	var position_b := Vector2.ZERO
	for i in POINT_COUNT:
		position_a += points_a[i] * ga[i]
		position_b += points_b[i] * gb[i]
	var depth: float = contact.margin - (position_b - position_a).dot(normal)
	if depth < -0.02:
		return

	# This manifold is discarded at the next substep. Weights, mass and
	# predicted velocities stay fixed during the iterations of this substep.
	if not contact.has("script_key"):
		var ball_a: MergeBall = a.ball
		var ball_b: MergeBall = b.ball
		var key := str(ball_a.get_instance_id()) + ":" + str(ball_b.get_instance_id())
		contact.script_key = key
		contacts[key] = [ball_a, ball_b, normal]
	if depth <= 0.0:
		return
	if not contact.has("script_denominator"):
		var wa: float = POINT_COUNT / a.ball.mass
		var wb: float = POINT_COUNT / b.ball.mass
		var denominator := 0.0
		for i in POINT_COUNT:
			denominator += wa * ga[i] * ga[i] + wb * gb[i] * gb[i]
		var relative_velocity := _weighted_velocity(b, gb) - _weighted_velocity(a, ga)
		contact.script_mass_a = wa
		contact.script_mass_b = wb
		contact.script_denominator = maxf(denominator, 0.000001)
		contact.script_allowed = maxf(1.0, maxf(0.0, -relative_velocity.dot(normal)) * a.step_dt)

	var dl: float = depth / contact.script_denominator
	var stabilization := clampf((depth - contact.script_allowed) / maxf(depth, 0.000001), 0.0, 1.0)
	_correct_surface(a, ga, -normal * contact.script_mass_a * dl, stabilization)
	_correct_surface(b, gb, normal * contact.script_mass_b * dl, stabilization)

func _contact_position(s: Dictionary, weights: PackedFloat32Array) -> Vector2:
	if kernel == null: return super._contact_position(s, weights)
	return kernel.weighted(s.points, weights)

func _weighted_velocity(s: Dictionary, weights: PackedFloat32Array) -> Vector2:
	if kernel == null: return super._weighted_velocity(s, weights)
	return kernel.weighted(s.velocities, weights)

func _correct_surface(s: Dictionary, weights: PackedFloat32Array, correction: Vector2, stabilization := 0.0) -> void:
	if kernel == null:
		super._correct_surface(s, weights, correction, stabilization)
		return
	kernel.correct_surface(s, weights, correction, stabilization)
