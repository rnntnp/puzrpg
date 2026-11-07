extends "res://scripts/gimmicks/visuals/soft_pond_layer.gd"

# Standard Quark polygon particles; no affine binding or post-solve guards.
# Quark uses displacement per update. The bridge converts pixels/second and
# pixels/second² at a fixed 60 Hz, without a second Godot collision solver.
const STEP := 1.0 / 60.0
const QUERY_LAYER := 1 << 19
var step_seconds := STEP
var world: Node2D
var native_to_game: Dictionary = {}
var native_contacts: Dictionary = {}
var publish_geometry := true

func configure(board: MergeGame, settings: Resource) -> void:
	super.configure(board, settings)
	step_seconds=STEP/tuning.quark_substeps
	world = ClassDB.instantiate("QWorldNode")
	world.name = "QWorldNode"
	world.set("debug_renderer", false)
	world.set("gravity", Vector2.ZERO)
	world.set("iteration_count", tuning.quark_iterations)
	world.set("enable_sleeping", true)
	world.set_sleeping_position_tolerance(tuning.quark_sleep_tolerance)
	get_tree().current_scene.add_child(world)
	world.set_physics_process(false)
	var l := game.board_inner_left
	var r := game.board_inner_right
	var t := game.drop_position_y
	var b := game.board_inner_bottom
	_wall(Rect2(l-100,t-100,100,b-t+200),game.left_wall)
	_wall(Rect2(r,t-100,100,b-t+200),game.right_wall)
	_wall(Rect2(l,t-100,r-l,100),_ceiling())
	_wall(Rect2(l,b,r-l,100),game.floor_body)

func _mesh(outline: PackedVector2Array, soft: bool) -> Node2D:
	var mesh: Node2D = ClassDB.instantiate("QMeshNode")
	var points := outline.duplicate()
	var polygon := PackedInt32Array()
	var springs: Array[PackedInt32Array] = []
	var internal: Array[PackedInt32Array] = []
	for i in outline.size():
		polygon.append(i)
		springs.append(PackedInt32Array([i,(i+1)%outline.size()]))
		if soft:
			internal.append(PackedInt32Array([i,(i+2)%outline.size()]))
			if i<outline.size()/2:internal.append(PackedInt32Array([i,i+outline.size()/2]))
	var flags := PackedByteArray()
	flags.resize(points.size())
	mesh.set("data_particle_positions",points)
	mesh.set("data_particle_is_internal",flags)
	mesh.set("data_polygon",polygon)
	mesh.set("data_springs",springs)
	mesh.set("data_internal_springs",internal)
	mesh.set("enable_vector_rendering",false)
	mesh.set("enable_particle_rendering",false)
	return mesh

func _sample_outline(outline: PackedVector2Array) -> PackedVector2Array:
	var lengths := PackedFloat32Array([0.0])
	for i in outline.size():lengths.append(lengths[-1]+outline[i].distance_to(outline[(i+1)%outline.size()]))
	var rest := PackedVector2Array()
	for i in tuning.quark_particle_count:
		var distance: float = lengths[-1]*i/tuning.quark_particle_count
		var edge := 0
		while edge+1<outline.size() and lengths[edge+1]<distance:edge+=1
		rest.append(outline[edge].lerp(outline[(edge+1)%outline.size()],(distance-lengths[edge])/maxf(lengths[edge+1]-lengths[edge],0.001)))
	return rest

func _wall(rect: Rect2, original: Node) -> void:
	var body: Node2D = ClassDB.instantiate("QRigidBodyNode")
	body.set("mode",1)
	body.set("layers",2 if original in [game.left_wall,game.right_wall] else 4)
	body.set("collidable_layers",0)
	body.set("friction",tuning.quark_wall_friction)
	var corners := PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
	for i in corners.size(): corners[i]=game.to_global(corners[i])
	body.add_child(_mesh(corners,false))
	world.add_child(body)
	native_to_game[body.get_instance_id()]=original

func _register(ball: MergeBall) -> void:
	# Reuse visual installation and Godot-query cleanup, then replace the
	# inherited six-point state with ordinary independent Quark particles.
	super._register(ball)
	var s: Dictionary = states[ball.get_instance_id()]
	s.rest = _sample_outline(s.outline_rest)
	s.points = PackedVector2Array()
	s.velocities = PackedVector2Array()
	ball.collision_layer=QUERY_LAYER
	s.collider.name="QuarkQuerySilhouette"
	s.collider.shape.points=s.rest
	var body: Node2D = ClassDB.instantiate("QSoftBodyNode")
	body.position=ball.global_position
	body.rotation=ball.global_rotation
	body.set("mass",ball.mass)
	body.set("rigidity",tuning.quark_rigidity)
	body.set("shape_matching",true)
	body.set("shape_matching_rate",tuning.quark_shape_matching)
	body.set("area_preserving",true)
	body.set("area_preserving_rigidity",tuning.quark_area_rigidity)
	body.set("area_preserving_rate",1.0)
	body.set("friction",tuning.quark_friction)
	body.set("restitution",0.0)
	body.set("use_custom_gravity",true)
	var mesh := _mesh(s.rest,true)
	body.add_child(mesh)
	world.add_child(body)
	mesh.set_min_angle_constraint_of_polygon(0.0)
	var particles: Array = []
	var controls := PackedInt32Array()
	for i in s.rest.size():
		var p: Object = mesh.get_particle_at(i)
		var rest: Vector2 = s.rest[i]
		var velocity: Vector2 = ball.linear_velocity+Vector2(-rest.y,rest.x).rotated(ball.global_rotation)*ball.angular_velocity
		p.set_previous_global_position(p.get_global_position()-velocity*step_seconds)
		particles.append(p)
		controls.append(i)
		s.points.append(p.get_global_position())
		s.velocities.append(velocity)
	s.previous=s.points.duplicate()
	# Keep diagnostic edge data in sync with the standard physical mesh.
	s.edges=[]
	for i in s.rest.size():
		for gap in [1,2]:
			var j: int = (i+gap)%s.rest.size()
			s.edges.append({"i":i,"j":j,"length":s.rest[i].distance_to(s.rest[j])})
		if i<s.rest.size()/2:
			var j: int = i+s.rest.size()/2
			s.edges.append({"i":i,"j":j,"length":s.rest[i].distance_to(s.rest[j])})
	s.merge({"native":body,"particles":particles,"surface_particles":particles,"controls":controls,"native_sleeping":false})
	native_to_game[body.get_instance_id()]=ball
	body.connect("collision",_on_native_contact)

func _on_native_contact(body: Object, info: Dictionary) -> void:
	var a: Node = native_to_game.get(body.get_instance_id())
	var b: Node = native_to_game.get(info.body.get_instance_id())
	if not is_instance_valid(a) or not is_instance_valid(b):return
	var key := Vector2i(mini(a.get_instance_id(),b.get_instance_id()),maxi(a.get_instance_id(),b.get_instance_id()))
	native_contacts[key]=[a,b]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(world):return
	accumulated_time+=delta
	if accumulated_time<STEP-0.000001:return
	accumulated_time=0.0
	for substep in tuning.quark_substeps:
		publish_geometry=substep==tuning.quark_substeps-1
		_step_native()

func _step_native() -> void:
	for ball in game.get_active_balls():
		if ball is MergeBall and not ball.merge_locked and not states.has(ball.get_instance_id()):_register(ball)
	var active: Array = []
	for id in states.keys():
		var s: Dictionary = states[id]
		if not is_instance_valid(s.ball):
			native_to_game.erase(s.native.get_instance_id())
			s.native.free()
			states.erase(id)
			continue
		s.native.set("enabled",not s.ball.merge_locked and not s.ball.is_ice_frozen)
		if s.ball.merge_locked or s.ball.is_ice_frozen:continue
		s.seen={}
		_import_native(s)
		active.append(s)
	native_contacts.clear()
	world.update_world()
	_reflect_flight_sides(active)
	for s in active:
		_read_native(s)
	for s in active:
		if not s.native.get_is_sleeping() or not s.native_sleeping:_publish(s)
		elif s.visuals.install_pending():s.visuals.update_surface(s,tuning)
		s.native_sleeping=s.native.get_is_sleeping()
	for pair in native_contacts.values():
		for ball in pair:
			if ball is MergeBall:ball.notify_custom_contact()
	for pair in native_contacts.values():
		var a: Node = pair[0]; var b: Node = pair[1]
		if a is MergeBall:_notify(a,b)
		if b is MergeBall:_notify(b,a)
		if a is MergeBall and b is MergeBall:a.request_merge_with(b)
	for s in active:s.touching=s.seen

func _import_native(s: Dictionary) -> void:
	var ball: MergeBall = s.ball
	var impulse := ball.linear_velocity-Vector2(s.published_velocity)
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity",980.0)
	var acceleration := Vector2(0,gravity*ball.gravity_scale)+ball.constant_force/ball.mass
	if not is_equal_approx(s.native.get("mass"),ball.mass):s.native.set("mass",ball.mass)
	var changed: bool = s.get("external_force",acceleration)!=acceleration
	var shift := Vector2.ZERO
	if ball.global_position.distance_to(s.center)>maxf(30.0,s.radius):shift=ball.global_position-s.center
	if impulse.length_squared()>0.0001 or changed or shift!=Vector2.ZERO:
		s.native.wake_up()
		for p in s.particles:
			p.set_global_position(p.get_global_position()+shift)
			p.set_previous_global_position(p.get_previous_global_position()+shift-impulse*step_seconds)
	s.external_force=acceleration
	s.native.set("custom_gravity",acceleration*step_seconds*step_seconds)
	s.native.set("collidable_layers",5 if ball.get_meta("directional_flight",false) else 7)
	s.native.set("air_friction",1.0-exp(-(ball.linear_damp+tuning.quark_air_damping)*step_seconds))
	s.pre_velocity=s.published_velocity+impulse

func _reflect_flight_sides(active: Array) -> void:
	# A directional shot retains the stage's elastic, straight side reflection.
	# Native soft contacts take over after its first non-side contact. Mirror the
	# substep overshoot as the guide does, avoiding loss into deformation modes.
	for s in active:
		var ball: MergeBall = s.ball
		if not ball.get_meta("directional_flight",false):continue
		var left := INF; var right := -INF
		for p in s.surface_particles:
			var point: Vector2 = game.to_local(p.get_global_position())
			left=minf(left,point.x); right=maxf(right,point.x)
		var wall: Node
		var shift := Vector2.ZERO
		if left<game.board_inner_left and s.pre_velocity.x<0:
			wall=game.left_wall
			shift.x=2.0*(game.board_inner_left-left)
		elif right>game.board_inner_right and s.pre_velocity.x>0:
			wall=game.right_wall
			shift.x=2.0*(game.board_inner_right-right)
		else:continue
		shift=game.global_transform.basis_xform(shift)
		for p in s.particles:
			var position: Vector2 = p.get_global_position()
			var velocity: Vector2 = (position-p.get_previous_global_position())/step_seconds
			velocity.x=-velocity.x
			p.set_global_position(position+shift)
			p.set_previous_global_position(position+shift-velocity*step_seconds)
		native_contacts[Vector2i(ball.get_instance_id(),wall.get_instance_id())]=[ball,wall]







func _read_native(s: Dictionary) -> void:
	for i in s.rest.size():
		var p: Object = s.particles[s.controls[i]]
		s.points[i]=p.get_global_position()
		s.velocities[i]=(p.get_global_position()-p.get_previous_global_position())/step_seconds
	s.surface_dirty=true

func _publish(s: Dictionary) -> void:
	var ball: MergeBall = s.ball
	var center := _center(s.points)
	var rest_center := _center(s.rest)
	var cross := 0.0; var dot := 0.0
	for i in s.rest.size():
		var rest: Vector2 = s.rest[i]-rest_center
		cross+=rest.cross(s.points[i]-center)
		dot+=rest.dot(s.points[i]-center)
	var angle: float = s.rotation if ball.lock_rotation else atan2(cross,dot)
	var origin: Vector2 = center-rest_center.rotated(angle)
	ball.global_position=origin
	ball.global_rotation=angle
	ball.linear_velocity=_center(s.velocities)
	ball.angular_velocity=0.0
	s.center=origin
	s.published_velocity=ball.linear_velocity
	# Intermediate substeps need the game pose for impulses/contact callbacks,
	# but the query hull and GPU surface are only consumed after the outer step.
	if not publish_geometry:return
	var local := PackedVector2Array()
	for p in s.points:local.append((p-origin).rotated(-angle))
	var outline := PackedVector2Array()
	for p in _surface(s):outline.append((p-origin).rotated(-angle))
	var hull := Geometry2D.convex_hull(outline)
	if hull.size()>1:hull.remove_at(hull.size()-1)
	s.collider.shape.points=hull
	s.surface_points=local
	s.visuals.update_surface(s,tuning)

func _surface(s: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in s.surface_particles:result.append(p.get_global_position())
	return result

func restore_balls() -> void:
	super.restore_balls()
	native_to_game.clear()
	native_contacts.clear()
	if is_instance_valid(world):
		# A new enemy can configure its handler in this same frame. Remove the
		# old world immediately so new native bodies cannot discover it.
		if world.get_parent()!=null:world.get_parent().remove_child(world)
		world.queue_free()

func integrate_flight_velocity(velocity: Vector2,acceleration: Vector2,damp: float,dt: float) -> Vector2:
	return velocity*exp(-(damp+tuning.quark_air_damping)*dt)+acceleration*dt
