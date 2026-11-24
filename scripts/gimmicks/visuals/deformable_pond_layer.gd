extends "res://scripts/gimmicks/visuals/quark_pond_layer.gd"
## Standard Quark soft polygons resolve actual motion and collision.
const Faces = preload("res://scripts/gimmicks/visuals/deformable_pond_faces.gd")
const Outline = preload("res://scripts/gimmicks/visuals/deformable_pond_outline.gd")

func _outline(ball: MergeBall) -> Dictionary:
	var data := super._outline(ball)
	# All levels use the rendered shell's outer colored boundary, including
	# its vertex expansion. Catalog circles are not a reliable visual fit.
	var chain := Outline.shell_chain(ball, tuning.quark_particle_count, true)
	if chain.size()<3: return data
	data.outline = chain
	# The inherited registration briefly needs six controls before Quark
	# replaces them with the independent boundary particles.
	data.rest = Outline.simplify(chain, POINT_COUNT)
	return data

func _sample_outline(outline: PackedVector2Array) -> PackedVector2Array:
	var sampled:=outline.duplicate() if outline.size()==tuning.quark_particle_count else super._sample_outline(outline)
	var canvas_scale:=get_global_transform_with_canvas().x.length()/maxf(global_transform.x.length(),0.001)
	var padding: float=tuning.collision_padding_px/maxf(canvas_scale,0.001)
	if padding<=0.0:return sampled
	# Move the physical rest chain outward, not the sprite. The visual shader
	# receives (current - rest) offsets, so its undeformed artwork stays its
	# original size. Queries, wall reflection and broadphase use this same chain.
	var expanded:=Geometry2D.offset_polygon(sampled,padding,Geometry2D.JOIN_ROUND)
	if expanded.is_empty():return sampled
	var largest: PackedVector2Array=expanded[0]
	for polygon: PackedVector2Array in expanded:
		if absf(_polygon_area(polygon))>absf(_polygon_area(largest)):largest=polygon
	return Outline.simplify(largest,tuning.quark_particle_count)

func _polygon_area(polygon: PackedVector2Array) -> float:
	var area:=0.0
	for i in polygon.size():area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return area*0.5

func configure(board: MergeGame, settings: Resource) -> void:
	# Live debug controls must not mutate the shared Resource for other scenes.
	super.configure(board, settings.duplicate())
	world.set_spatial_hashing_cell_size(tuning.spatial_cell_size)
	world.set_spatial_hashing_enabled(tuning.spatial_partition)
	world.set_bounded_search_enabled(tuning.centroid_bound_search)

func _register(ball: MergeBall) -> void:
	var face_layers := Faces.split(ball)
	super._register(ball)
	states[ball.get_instance_id()].face_layers = face_layers
	var state: Dictionary = states[ball.get_instance_id()]
	var center := _center(state.rest)
	state.bound_radius = 0.0
	for point in state.rest:
		state.bound_radius = maxf(state.bound_radius, point.distance_to(center))
	world.set_body_search_radius(state.native, state.bound_radius*tuning.deformation_hard_ratio)

func _prepare_state(ball: MergeBall) -> Dictionary:
	var data := _outline(ball)
	var rest := _sample_outline(data.outline)
	var visuals := SoftVisuals.new()
	visuals.configure(ball)
	var original := {"mask":ball.collision_mask,"layer":ball.collision_layer,"integrator":ball.custom_integrator,"ccd":ball.continuous_cd}
	ball.custom_integrator = true
	ball.collision_mask = 0
	ball.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	for shape in data.shapes: shape.node.disabled = true
	var collider := CollisionShape2D.new()
	collider.name = "QuarkQuerySilhouette"
	collider.shape = ConvexPolygonShape2D.new()
	ball.add_child(collider)
	var state := {"ball":ball,"rest":rest,"outline_rest":data.outline,"visuals":visuals,"original":original,"shapes":data.shapes,"collider":collider,"center":ball.global_position,"rotation":ball.global_rotation,"published_velocity":ball.linear_velocity,"applied":Transform2D.IDENTITY,"boundary":{},"touching":{},"radius":ball.get_radius(),"surface_dirty":true}
	states[ball.get_instance_id()] = state
	return state

func _import_native(state: Dictionary) -> void:
	super._import_native(state)
	world.set_body_search_radius(state.native, state.bound_radius*tuning.deformation_hard_ratio)

func _read_native(state: Dictionary) -> void:
	var snapshot: Dictionary = world.read_soft_body_state(state.native, step_seconds, state.bound_radius,
		tuning.deformation_soft_ratio, tuning.deformation_hard_ratio, tuning.deformation_return_rate,
		tuning.bounded_deformation and not state.native.get_is_sleeping(),
		0.0 if state.native.get_is_sleeping() else tuning.particle_internal_damping,
		state.rest, tuning.particle_deformation_limit if not state.native.get_is_sleeping() else 0.0)
	state.points = snapshot.points
	state.velocities = snapshot.velocities
	state.surface_dirty = true

func _surface(state: Dictionary) -> PackedVector2Array:
	# Debug drawing closes its returned polygon by appending the first point.
	# Keep the physical snapshot at exactly one entry per native particle.
	if state.has("native"): return state.points.duplicate()
	return super._surface(state)

func _publish_visuals(state: Dictionary) -> void:
	state.render_dirty = true

func _process(_delta: float) -> void:
	for state: Dictionary in states.values():
		if not is_instance_valid(state.ball) or not state.get("render_dirty", false): continue
		state.visuals.update_surface(state, tuning)
		Faces.update(state, tuning)
		state.render_dirty = false

func restore_balls() -> void:
	# The extension owns the hash buckets; detach them before native bodies
	# are destroyed during a scene transition.
	if is_instance_valid(world):
		world.set_bounded_search_enabled(false)
		world.set_spatial_hashing_enabled(false)
	var old_states: Array = states.values()
	super.restore_balls()
	Faces.restore(old_states)

func _exit_tree() -> void:
	# The scene parent is already removing children here; avoid removing a
	# sibling synchronously in the inherited normal handler-cleanup path.
	var departing_world := world
	if is_instance_valid(departing_world):
		departing_world.set_bounded_search_enabled(false)
		departing_world.set_spatial_hashing_enabled(false)
	world = null
	restore_balls()
	if is_instance_valid(departing_world): departing_world.queue_free()
