extends Node2D

const SoftVisuals = preload("res://scripts/gimmicks/visuals/soft_pond_meshes.gd")
const POINT_COUNT := 6
var game: MergeGame
var tuning: Resource
var states: Dictionary = {}
var contacts: Dictionary = {}
var manifolds: Dictionary = {}
var sleeping := false
var quiet_time := 0.0
var accumulated_time := 0.0
var ceiling_body: Node

func configure(board: MergeGame, settings: Resource) -> void:
	game = board
	tuning = settings

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	# Fixed 60 Hz material solve, with 120 Hz particle substeps by default.
	# Avoid doubling the whole soft solver when the project's rigid tick is 120.
	accumulated_time+=delta
	if accumulated_time<1.0/60.0-0.000001:return
	delta=accumulated_time
	accumulated_time=0.0
	for ball in game.get_active_balls():
		if ball is MergeBall and not ball.merge_locked and not states.has(ball.get_instance_id()): _register(ball)
	for id in states.keys():
		if not is_instance_valid(states[id].ball):
			states.erase(id)
			sleeping=false
	var active: Array = []
	for s in states.values():
		if not s.ball.merge_locked and not s.ball.is_ice_frozen:
			_import_changes(s)
			s.seen = {}
			active.append(s)
	if sleeping:
		for s in active:
			if s.visuals.install_pending():s.visuals.update_surface(s,tuning)
		return
	contacts.clear()
	var dt: float = minf(delta, 0.05) / tuning.solver_substeps
	for substep in tuning.solver_substeps:
		manifolds.clear()
		for s in active:
			s.wall_manifolds=[]
			_predict(s, dt)
		var pairs := _candidate_pairs(active,dt)
		for iteration in tuning.solver_iterations:
			for s in active: _structure(s, dt)
			for s in active: _walls(s)
			for pair in pairs:_collide(pair[0],pair[1])
		for s in active: _velocity(s, dt)
		_damp_contacts(active,dt)
	for s in active: _publish(s)
	# body_entered can synchronously lock both merge sources. Deliver every
	# landing notification first, including the newly launched second source.
	for pair in contacts.values():
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			pair[0].notify_custom_contact()
			pair[1].notify_custom_contact()
	for pair in contacts.values():
		var a: MergeBall = pair[0]
		var b: MergeBall = pair[1]
		if is_instance_valid(a) and is_instance_valid(b) and not a.merge_locked and not b.merge_locked:
			_notify(a,b)
			_notify(b,a)
			a.request_merge_with(b)
	for s in active:s.touching=s.seen
	_update_sleep(active,delta)

func _update_sleep(active: Array,dt: float) -> void:
	# Sleep the interacting system as one unit, only after its kinetic energy
	# stays below a numerical tolerance. New impulses, force changes or spawns
	# wake it as one unit too, so a sleeping contact cannot fight an awake one.
	var quiet := not active.is_empty()
	for s in active:
		var square := 0.0
		for v in s.velocities:square+=v.length_squared()/POINT_COUNT
		if square>tuning.sleep_velocity*tuning.sleep_velocity:quiet=false
		if _center(s.velocities).length()>tuning.sleep_velocity*0.5:quiet=false
		if s.touching.is_empty():
			for edge in s.edges:
				if absf(s.points[edge.i].distance_to(s.points[edge.j])-edge.length)>0.001*edge.length:quiet=false
	quiet_time=quiet_time+dt if quiet else 0.0
	if quiet_time<tuning.sleep_delay:return
	sleeping=true
	for s in active:
		for i in POINT_COUNT:s.velocities[i]=Vector2.ZERO
		s.ball.linear_velocity=Vector2.ZERO
		s.published_velocity=Vector2.ZERO

func _outline(ball: MergeBall) -> Dictionary:
	var points := PackedVector2Array()
	var shapes: Array = []
	for node in ball.get_children():
		if not node is CollisionShape2D or node.disabled or node.shape == null: continue
		shapes.append({"node":node,"shape":node.shape,"transform":node.transform,"disabled":node.disabled})
		var p := PackedVector2Array()
		if node.shape is ConvexPolygonShape2D: p = node.shape.points
		elif node.shape is CircleShape2D:
			for i in 32: p.append(Vector2.from_angle(TAU*i/32.0)*node.shape.radius)
		elif node.shape is CapsuleShape2D:
			var stem: float = maxf(0,node.shape.height*0.5-node.shape.radius)
			for i in 17: p.append(Vector2.from_angle(PI+PI*i/16.0)*node.shape.radius+Vector2(0,-stem))
			for i in 17: p.append(Vector2.from_angle(PI*i/16.0)*node.shape.radius+Vector2(0,stem))
		elif node.shape is RectangleShape2D:
			var h: Vector2 = node.shape.size*0.5
			p = PackedVector2Array([Vector2(-h.x,-h.y),Vector2(h.x,-h.y),h,Vector2(-h.x,h.y)])
		for point in p: points.append(node.transform*point)
	var hull := Geometry2D.convex_hull(points)
	if hull.size()>1: hull.remove_at(hull.size()-1)
	var lengths := PackedFloat32Array([0.0])
	for i in hull.size(): lengths.append(lengths[-1]+hull[i].distance_to(hull[(i+1)%hull.size()]))
	var rest := PackedVector2Array()
	for i in POINT_COUNT:
		var distance := lengths[-1]*i/POINT_COUNT
		var edge := 0
		while edge+1<hull.size() and lengths[edge+1]<distance: edge+=1
		rest.append(hull[edge].lerp(hull[(edge+1)%hull.size()],(distance-lengths[edge])/maxf(lengths[edge+1]-lengths[edge],0.001)))
	return {"rest":rest,"shapes":shapes,"outline":hull}

func _register(ball: MergeBall) -> void:
	sleeping=false
	quiet_time=0.0
	var data := _outline(ball)
	var rest: PackedVector2Array = data.rest
	if rest.size()!=POINT_COUNT: return
	var points := PackedVector2Array()
	for p in rest: points.append(ball.global_transform*p)
	var edges: Array = []
	for i in POINT_COUNT:
		for j in range(i+1,POINT_COUNT):
			var gap := mini(j-i, POINT_COUNT-(j-i))
			if not gap in [1,2,4,POINT_COUNT / 2]:continue
			edges.append({"i":i,"j":j,"length":rest[i].distance_to(rest[j]),"lambda":0.0,"edge":j==i+1 or (i==0 and j==POINT_COUNT-1)})
	var edge_i := PackedInt32Array()
	var edge_j := PackedInt32Array()
	var edge_lengths := PackedFloat32Array()
	var edge_compliances := PackedFloat32Array()
	var edge_lambdas := PackedFloat32Array()
	for edge in edges:
		edge_i.append(edge.i)
		edge_j.append(edge.j)
		edge_lengths.append(edge.length)
		edge_compliances.append(tuning.edge_compliance if edge.edge else tuning.shape_compliance)
		edge_lambdas.append(0.0)
	var visuals := SoftVisuals.new()
	visuals.configure(ball)
	var original := {"mask":ball.collision_mask,"layer":ball.collision_layer,"integrator":ball.custom_integrator,"ccd":ball.continuous_cd}
	# Godot still exposes the silhouette to guide queries and receives gameplay
	# impulses, but only this solver resolves motion and soft contacts.
	ball.custom_integrator = true
	ball.collision_mask = 0
	ball.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	for shape in data.shapes: shape.node.disabled = true
	var collider := CollisionShape2D.new()
	collider.name = "XPBDSilhouette"
	collider.shape = ConvexPolygonShape2D.new()
	collider.shape.points = data.outline
	ball.add_child(collider)
	var velocities := PackedVector2Array()
	velocities.resize(POINT_COUNT)
	for i in POINT_COUNT: velocities[i] = ball.linear_velocity + Vector2(-rest[i].y,rest[i].x).rotated(ball.global_rotation)*ball.angular_velocity
	states[ball.get_instance_id()] = {"ball":ball,"rest":rest,"points":points,"previous":points.duplicate(),"velocities":velocities,"edges":edges,"area":_area(rest),"area_lambda":0.0,"center":ball.global_position,"published_velocity":ball.linear_velocity,"rotation":ball.global_rotation,"collider":collider,"shapes":data.shapes,"original":original,"visuals":visuals,"applied":Transform2D.IDENTITY,"boundary":{},"touching":{},"radius":ball.get_radius()}
	states[ball.get_instance_id()].merge({"edge_i":edge_i,"edge_j":edge_j,"edge_lengths":edge_lengths,"edge_compliances":edge_compliances,"edge_lambdas":edge_lambdas})
	var bindings: Array[Vector4] = []
	for p in data.outline:bindings.append(_bind_outline(p,rest))
	bindings.sort_custom(func(a:Vector4,b:Vector4)->bool:return a.x<b.x)
	var sectors: Array[PackedVector2Array] = []
	for i in POINT_COUNT:sectors.append(PackedVector2Array())
	for binding in bindings:sectors[int(binding.x)].append(Vector2(binding.z,binding.w))
	states[ball.get_instance_id()].sectors=sectors
	states[ball.get_instance_id()].merge({"outline_rest":data.outline,"outline_bindings":bindings,"surface_dirty":true,"contact_surface":PackedVector2Array(),"query_shape":ConvexPolygonShape2D.new(),"query_dirty":true})

func _bind_outline(point: Vector2,rest: PackedVector2Array) -> Vector4:
	var center := _center(rest)
	var p := point-center
	for i in POINT_COUNT:
		var j := (i+1)%POINT_COUNT
		var a := rest[i]-center
		var b := rest[j]-center
		var determinant := a.cross(b)
		if absf(determinant)<0.000001:continue
		var x := p.cross(b)/determinant
		var y := a.cross(p)/determinant
		if x>=-0.00001 and y>=-0.00001:return Vector4(i,j,x,y)
	return Vector4(0,1,0,0)

func _surface(s: Dictionary) -> PackedVector2Array:
	if not s.surface_dirty:return s.contact_surface
	var center := _center(s.points)
	var points: PackedVector2Array = s.points
	var result := PackedVector2Array()
	var sectors: Array[PackedVector2Array] = s.sectors
	for i in POINT_COUNT:
		var mapping := Transform2D(points[i]-center,points[(i+1)%POINT_COUNT]-center,center)
		result.append_array(mapping*sectors[i])
	var minimum := result[0]
	var maximum := minimum
	for p in result:
		minimum=minimum.min(p)
		maximum=maximum.max(p)
	s.surface_bounds=Rect2(minimum,maximum-minimum)
	s.contact_surface=result
	s.surface_dirty=false
	s.query_dirty=true
	return result

func _surface_gradient(s: Dictionary,indices: Array[int]) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	weights.resize(POINT_COUNT)
	for index in indices:
		var binding: Vector4 = s.outline_bindings[index]
		var base := (1.0-binding.z-binding.w)/POINT_COUNT/indices.size()
		for i in POINT_COUNT:weights[i]+=base
		weights[int(binding.x)]+=binding.z/indices.size()
		weights[int(binding.y)]+=binding.w/indices.size()
	return weights

func _correct_surface(s: Dictionary,weights: PackedFloat32Array,correction: Vector2) -> void:
	var points: PackedVector2Array = s.points
	for i in POINT_COUNT:points[i]+=weights[i]*correction
	s.points=points
	s.surface_dirty=true

func _import_changes(s: Dictionary) -> void:
	var ball: MergeBall = s.ball
	var impulse: Vector2 = ball.linear_velocity-s.published_velocity
	if impulse.length_squared()>0.0001 or s.get("external_force",ball.constant_force)!=ball.constant_force or s.get("external_gravity",ball.gravity_scale)!=ball.gravity_scale:
		sleeping=false
		quiet_time=0.0
	s.external_force=ball.constant_force
	s.external_gravity=ball.gravity_scale
	# Accept external repositioning, but ignore Godot's extra pose extrapolation.
	var shift := Vector2.ZERO
	if ball.global_position.distance_to(s.center)>maxf(30.0,s.radius):
		shift=ball.global_position-s.center
		sleeping=false
		quiet_time=0.0
	for i in POINT_COUNT:
		s.velocities[i]+=impulse
		s.points[i]+=shift
	s.surface_dirty=true

func _predict(s: Dictionary, dt: float) -> void:
	var ball: MergeBall = s.ball
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity",980.0)
	var acceleration := Vector2(0,gravity*ball.gravity_scale)+ball.constant_force/ball.mass
	var mean := Vector2.ZERO
	for v in s.velocities: mean+=v/POINT_COUNT
	var center := _center(s.points)
	var angular := 0.0
	var inertia := 0.0
	for i in POINT_COUNT:
		var r: Vector2 = s.points[i]-center
		angular+=r.cross(s.velocities[i]-mean)
		inertia+=r.length_squared()
	angular=0.0 if ball.lock_rotation else angular/maxf(inertia,0.001)
	angular*=exp(-ball.angular_damp*dt)
	var rigid_damp := exp(-ball.linear_damp*dt)
	var internal_damp := exp(-tuning.internal_damping*dt)
	s.previous=s.points.duplicate()
	for i in POINT_COUNT:
		var r: Vector2 = s.points[i]-center
		var rigid := mean+Vector2(-r.y,r.x)*angular
		s.velocities[i]=rigid*rigid_damp+(s.velocities[i]-rigid)*internal_damp+acceleration*dt
		s.points[i]+=s.velocities[i]*dt
	var lambdas: PackedFloat32Array = s.edge_lambdas
	lambdas.fill(0.0)
	s.edge_lambdas=lambdas
	s.area_lambda=0.0
	s.boundary.clear()
	s.surface_dirty=true

func _structure(s: Dictionary, dt: float) -> void:
	var weight: float = POINT_COUNT/s.ball.mass
	var points: PackedVector2Array = s.points
	var indices_i: PackedInt32Array = s.edge_i
	var indices_j: PackedInt32Array = s.edge_j
	var lengths: PackedFloat32Array = s.edge_lengths
	var compliances: PackedFloat32Array = s.edge_compliances
	var lambdas: PackedFloat32Array = s.edge_lambdas
	for index in indices_i.size():
		var i := indices_i[index]
		var j := indices_j[index]
		var difference: Vector2 = points[i]-points[j]
		var length := difference.length()
		if length<0.001: continue
		var compliance := compliances[index]
		var rest_length := lengths[index]
		var error := length-rest_length
		var limit: float = rest_length*tuning.maximum_compression
		if absf(error)>limit:
			var hard_correction := difference/length*(error-clampf(error,-limit,limit))*0.5
			points[i]-=hard_correction
			points[j]+=hard_correction
			continue
		var alpha := compliance/(dt*dt)
		var dl: float = (-(length-rest_length)-alpha*lambdas[index])/(2.0*weight+alpha)
		lambdas[index]+=dl
		var correction := difference/length*(weight*dl)
		points[i]+=correction
		points[j]-=correction
	var gradients := PackedVector2Array()
	var denominator := 0.0
	var scale: float = sqrt(absf(s.area))
	for i in POINT_COUNT:
		var d: Vector2 = points[(i+1)%POINT_COUNT]-points[(i+POINT_COUNT-1)%POINT_COUNT]
		var g := Vector2(d.y,-d.x)*0.5/scale
		gradients.append(g)
		denominator+=weight*g.length_squared()
	var alpha: float = tuning.area_compliance/(dt*dt)
	var dl: float = (-(_area(points)-s.area)/scale-alpha*s.area_lambda)/(denominator+alpha)
	s.area_lambda+=dl
	for i in POINT_COUNT: points[i]+=gradients[i]*(weight*dl)
	s.points=points
	s.edge_lambdas=lambdas
	s.surface_dirty=true

func _walls(s: Dictionary) -> void:
	# Refresh support patches once per substep, as with ball contacts.
	# The plane constraint remains linear in the six material controls.
	if s.wall_manifolds.is_empty():
		var normals := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]
		var anchors := [Vector2(game.board_inner_left,0),Vector2(game.board_inner_right,0),Vector2(0,game.drop_position_y),Vector2(0,game.board_inner_bottom)]
		var bodies := [game.left_wall,game.right_wall,_ceiling(),game.floor_body]
		var surface := _surface(s)
		for plane in 4:
			var axis: Vector2 = game.global_transform.basis_xform(normals[plane])
			var normal := axis.normalized()
			var gradient := _surface_gradient(s,_support(surface,-normal))
			var denominator := 0.0
			for weight in gradient:denominator+=weight*weight
			s.wall_manifolds.append({"normal":normal,"gradient":gradient,"plane":game.to_global(anchors[plane]).dot(normal),"inverse_mass":1.0/maxf(denominator,0.000001),"body":bodies[plane]})
	for m in s.wall_manifolds:
		var normal: Vector2 = m.normal
		var gradient: PackedFloat32Array = m.gradient
		var depth: float = m.plane-_contact_position(s,gradient).dot(normal)
		if depth<=0.0:continue
		_correct_surface(s,gradient,normal*depth*m.inverse_mass)
		for i in POINT_COUNT:
			if absf(gradient[i])>0.02:s.boundary[i]=normal
		_notify(s.ball,m.body)

func _ceiling() -> Node:
	if not is_instance_valid(ceiling_body):ceiling_body=game.get_parent().find_child("ReverseDropCeiling",true,false)
	return ceiling_body

func _collide(a: Dictionary,b: Dictionary) -> void:
	var key := Vector2i(a.ball.get_instance_id(),b.ball.get_instance_id())
	if manifolds.has(key):
		_resolve_contact(a,b,manifolds[key])
		return
	var surface_a := _surface(a)
	var surface_b := _surface(b)
	if not (a.surface_bounds as Rect2).grow(0.02).intersects(b.surface_bounds,true):return
	# Native narrow phase avoids GDScript's quadratic vertex/edge projections.
	var hits := _query_shape(a).collide_and_get_contacts(Transform2D.IDENTITY,_query_shape(b),Transform2D.IDENTITY)
	if hits.is_empty():return
	var depth := 0.0
	var normal := Vector2.ZERO
	for i in range(0,hits.size()-1,2):
		var separation := hits[i+1]-hits[i]
		var length := separation.length()
		if length>depth:
			depth=length
			normal=separation/length
	if normal==Vector2.ZERO:return
	if (_center(b.points)-_center(a.points)).dot(normal)<0:normal=-normal
	var ia := _support(surface_a,normal)
	var ib := _support(surface_b,-normal)
	var ga := _surface_gradient(a,ia)
	var gb := _surface_gradient(b,ib)
	var offset := _contact_position(b,gb)-_contact_position(a,ga)
	var manifold := {"normal":normal,"ga":ga,"gb":gb,"margin":offset.dot(normal)+depth}
	manifolds[key]=manifold
	_resolve_contact(a,b,manifold)

func _contact_position(s: Dictionary,weights: PackedFloat32Array) -> Vector2:
	var point := Vector2.ZERO
	var points: PackedVector2Array = s.points
	for i in POINT_COUNT:point+=points[i]*weights[i]
	return point

func _resolve_contact(a: Dictionary,b: Dictionary,m: Dictionary) -> void:
	var normal: Vector2 = m.normal
	var ga: PackedFloat32Array = m.ga
	var gb: PackedFloat32Array = m.gb
	var depth: float = m.margin-(_contact_position(b,gb)-_contact_position(a,ga)).dot(normal)
	if depth < -0.02:return
	var wa: float = POINT_COUNT/a.ball.mass
	var wb: float = POINT_COUNT/b.ball.mass
	var denominator := 0.0
	for i in POINT_COUNT:denominator+=wa*ga[i]*ga[i]+wb*gb[i]*gb[i]
	var dl := maxf(depth,0.0)/maxf(denominator,0.000001)
	_correct_surface(a,ga,-normal*wa*dl)
	_correct_surface(b,gb,normal*wb*dl)
	contacts[str(a.ball.get_instance_id())+":"+str(b.ball.get_instance_id())]=[a.ball,b.ball,normal]

func _query_shape(s: Dictionary) -> ConvexPolygonShape2D:
	var shape: ConvexPolygonShape2D = s.query_shape
	if s.query_dirty:
		var hull := Geometry2D.convex_hull(s.contact_surface)
		if hull.size()>1:hull.remove_at(hull.size()-1)
		shape.points=hull
		s.query_dirty=false
	return shape

func _candidate_pairs(active: Array,dt: float) -> Array:
	var pairs: Array = []
	var grid: Dictionary = {}
	var tested: Dictionary = {}
	const CELL_SIZE := 128.0
	for i in active.size():
		var a: Dictionary = active[i]
		a.query_center=_center(a.points)
		var surface := _surface(a)
		var minimum: Vector2 = surface[0]
		var maximum := minimum
		for point in surface:
			minimum=minimum.min(point)
			maximum=maximum.max(point)
		var padding: float = 10.0+a.published_velocity.length()*dt
		var first := Vector2i(((minimum-Vector2.ONE*padding)/CELL_SIZE).floor())
		var last := Vector2i(((maximum+Vector2.ONE*padding)/CELL_SIZE).floor())
		# Insert all overlapped cells so even the largest balls are not missed.
		for x in range(first.x,last.x+1):
			for y in range(first.y,last.y+1):
				var cell := Vector2i(x,y)
				if not grid.has(cell):grid[cell]=[]
				for j in grid[cell]:
					var key := Vector2i(j,i)
					if tested.has(key):continue
					tested[key]=true
					var b: Dictionary = active[j]
					var reach: float = a.radius+b.radius+20.0+(a.published_velocity.length()+b.published_velocity.length())*dt
					if (a.query_center as Vector2).distance_squared_to(b.query_center)<reach*reach:pairs.append([b,a])
				grid[cell].append(i)
	return pairs

func _support(points: PackedVector2Array,axis: Vector2) -> Array[int]:
	var best := -INF
	for i in points.size():
		var value := points[i].dot(axis)
		best=maxf(best,value)
	var indices: Array[int] = []
	# A short contact manifold prevents the selected vertex from alternating
	# between adjacent endpoints on a nearly flat contact patch.
	for i in points.size():
		if best-points[i].dot(axis)<1.5:indices.append(i)
	return indices

func _velocity(s: Dictionary,dt: float) -> void:
	for i in POINT_COUNT:
		var v: Vector2 = (s.points[i]-s.previous[i])/dt
		if s.boundary.has(i):
			var n: Vector2 = s.boundary[i]
			var incoming: float = s.velocities[i].dot(n)
			var restitution: float = 1.0 if absf(n.x)>0.5 else tuning.contact_bounce
			v-=n*minf(v.dot(n),0.0)
			# Restitution applies to impacts, not gravity's tiny resting impulse.
			if incoming < -30.0: v+=n*(-incoming*restitution)
			if absf(n.y)>0.5:
				v.x*=exp(-12.0*dt)
		s.velocities[i]=v

func _damp_contacts(active: Array,dt: float) -> void:
	for pair in contacts.values():
		var a: Dictionary = states[pair[0].get_instance_id()]
		var b: Dictionary = states[pair[1].get_instance_id()]
		var normal: Vector2 = pair[2]
		var relative := _center(b.velocities)-_center(a.velocities)
		var inward := normal*minf(relative.dot(normal),0.0)
		var tangent := relative-normal*relative.dot(normal)
		var correction := inward+tangent*(1.0-exp(-tuning.internal_damping*dt))
		var wa: float = 1.0/a.ball.mass
		var wb: float = 1.0/b.ball.mass
		for i in POINT_COUNT:
			a.velocities[i]+=correction*wa/(wa+wb)
			b.velocities[i]-=correction*wb/(wa+wb)
	for s in active:
		if s.boundary.is_empty(): continue
		var mean := _center(s.velocities)
		var normal := Vector2.ZERO
		for n in s.boundary.values(): normal+=n
		if normal.length_squared()<0.01: continue
		normal=normal.normalized()
		var tangent := mean-normal*mean.dot(normal)
		# Coulomb friction consumes the tangential velocity using the contact's
		# normal correction budget, rather than a timer that freezes the body.
		var budget := 0.0
		for i in s.boundary:
			budget+=maxf(0.0,-s.velocities[i].dot(s.boundary[i]))
		var acceleration: Vector2 = s.ball.constant_force/s.ball.mass+Vector2(0,float(ProjectSettings.get_setting("physics/2d/default_gravity",980.0))*s.ball.gravity_scale)
		budget=maxf(budget,absf(acceleration.dot(normal))*dt)
		var correction := tangent.limit_length(budget*0.5)
		for i in POINT_COUNT:s.velocities[i]-=correction

func _publish(s: Dictionary) -> void:
	var ball: MergeBall = s.ball
	var center := _center(s.points)
	var velocity := _center(s.velocities)
	var cross := 0.0; var dot := 0.0
	for i in POINT_COUNT:
		cross+=s.rest[i].cross(s.points[i]-center)
		dot+=s.rest[i].dot(s.points[i]-center)
	var angle := atan2(cross,dot)
	if ball.lock_rotation: angle=s.rotation
	var origin := center - _center(s.rest).rotated(angle)
	ball.global_position=origin
	ball.global_rotation=angle
	ball.linear_velocity=velocity
	ball.angular_velocity=0.0
	s.center=origin
	s.published_velocity=velocity
	var local := PackedVector2Array()
	for p in s.points: local.append((p-origin).rotated(-angle))
	var outline := PackedVector2Array()
	for p in _surface(s):outline.append((p-origin).rotated(-angle))
	var hull := Geometry2D.convex_hull(outline)
	if hull.size()>1: hull.remove_at(hull.size()-1)
	(s.collider.shape as ConvexPolygonShape2D).points=hull
	s.surface_points=local
	s.visuals.update_surface(s,tuning)

func _notify(ball: MergeBall,body: Node) -> void:
	if body==null or ball.merge_locked:return
	var s: Dictionary = states.get(ball.get_instance_id(),{})
	if s.is_empty() or s.seen.has(body.get_instance_id()):return
	s.seen[body.get_instance_id()]=true
	if s.touching.has(body.get_instance_id()):return
	ball.body_entered.emit(body)
	ball.notify_custom_contact()

func _center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for p in points:center+=p/points.size()
	return center

func _area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():area+=points[i].cross(points[(i+1)%points.size()])*0.5
	return area

func restore_balls() -> void:
	set_physics_process(false)
	for s in states.values():
		if not is_instance_valid(s.ball):continue
		s.visuals.restore()
		s.ball.custom_integrator=s.original.integrator
		s.ball.collision_mask=s.original.mask
		s.ball.collision_layer=s.original.layer
		s.ball.continuous_cd=s.original.ccd
		for shape in s.shapes:
			if is_instance_valid(shape.node):shape.node.disabled=shape.disabled
		s.collider.queue_free()
	states.clear()
