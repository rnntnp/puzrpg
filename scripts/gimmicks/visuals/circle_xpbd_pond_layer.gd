extends Node2D
## Stage 62 retains its resource path, but no longer runs an XPBD solver.
## Only MergeBall.visual_container receives a warp. Bodies are never modified.
const WarpMeshes = preload("res://scripts/gimmicks/visuals/rigid_pond_warp_meshes.gd")
const Constraints = preload("res://scripts/gimmicks/visuals/pond_warp_constraints.gd")
const POINT_COUNT := 6
const ControlCage = preload("res://scripts/gimmicks/visuals/pond_control_cage.gd")
const MAX_CONTACTS := 4
var game: MergeGame
var tuning: Resource
var states: Dictionary = {}
var accumulated_time := 0.0
var pair_count := 0
var contact_generation := 0
var contact_shares: Dictionary = {}
static var gloss_attachment_cache: Dictionary = {}

func configure(board: MergeGame, settings: Resource) -> void:
	game = board
	tuning = settings

func _register(ball: MergeBall) -> void:
	var cage := ControlCage.build(ball, POINT_COUNT)
	var rest: PackedVector2Array = cage.rest
	var offsets := PackedVector2Array()
	var velocities := PackedVector2Array()
	for i in POINT_COUNT:
		offsets.append(Vector2.ZERO)
		velocities.append(Vector2.ZERO)
	var meshes := WarpMeshes.new()
	meshes.configure(ball)
	var observer := _capture_contacts.bind(ball.get_instance_id())
	var center := Vector2.ZERO
	for point in rest: center += point / POINT_COUNT
	var radius := 0.0
	for point in cage.outline: radius = maxf(radius,point.distance_to(center))
	states[ball.get_instance_id()] = {"ball": ball, "rest": rest, "offsets": offsets,
		"velocities": velocities, "contacts": [], "visuals": meshes,
		"previous_observer": ball.contact_observer, "observer": observer,
		"applied": Transform2D.IDENTITY, "surface_points": rest.duplicate(),
		"published_points": PackedVector2Array(), "anchors": [], "walls": [],
		"touching": {}, "press_contacts": {}, "release_pose": offsets.duplicate(), "release_weight": 0.0,
		"to_board": Transform2D.IDENTITY, "circle_center": center, "radius": radius,
		"last_velocity": ball.linear_velocity, "impact_change": Vector2.ZERO}

	_install_sprite_gloss(states[ball.get_instance_id()],cage.outline)
	ball.contact_observer = observer

func _capture_contacts(body: PhysicsDirectBodyState2D, id: int) -> void:
	if not states.has(id):
		return
	var record: Dictionary = states[id]
	if record.previous_observer.is_valid():
		record.previous_observer.call(body)
	# Separate collision response from ordinary force/damping acceleration.
	var acceleration: Vector2 = body.total_gravity + record.ball.constant_force*body.inverse_mass
	var expected: Vector2 = (record.last_velocity+acceleration*body.step)*maxf(0.0,1.0-body.total_linear_damp*body.step)
	var change: Vector2 = body.linear_velocity-expected
	# Preserve the short impulse across the 120 Hz physics / 60 Hz visual ticks.
	record.impact_change *= exp(-body.step/0.10)
	if change.length_squared()>record.impact_change.length_squared(): record.impact_change = change
	record.last_velocity = body.linear_velocity
	var contacts: Array = []
	for i in body.get_contact_count():
		var normal := body.get_contact_local_normal(i)
		var relative := body.get_contact_local_velocity_at_position(i) - body.get_contact_collider_velocity_at_position(i)
		var impulse_speed := body.get_contact_impulse(i).length() * body.inverse_mass
		var speed := maxf(absf(relative.dot(normal)), impulse_speed)
		var strength: float = tuning.resting_squash + tuning.impact_squash * clampf(speed / tuning.impact_speed, 0.0, 1.0)
		var outward := -body.transform.basis_xform_inv(normal).normalized()
		var merged := false
		for contact in contacts:
			if outward.dot(contact.direction) > 0.85:
				contact.strength = maxf(contact.strength, strength)
				merged = true
				break
		if not merged:
			contacts.append({"direction": outward, "strength": strength,
				"position": body.transform.affine_inverse() * body.get_contact_local_position(i),
				"other": body.get_contact_collider_id(i)})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.strength > b.strength)
	if contacts.size() > MAX_CONTACTS:
		contacts.resize(MAX_CONTACTS)
	record.contacts = contacts

func _physics_process(delta: float) -> void:
	accumulated_time += delta
	if accumulated_time < 1.0 / 60.0 - 0.000001:
		return
	delta = accumulated_time
	accumulated_time = 0.0
	if not is_instance_valid(game):
		return
	for ball in game.get_active_balls():
		if ball is MergeBall and not ball.merge_locked and not states.has(ball.get_instance_id()):
			_register(ball)
	for id in states.keys():
		if not is_instance_valid(states[id].ball): states.erase(id)
	var active := []
	for state in states.values():
		if state.ball.merge_locked: continue
		state.to_board = game.global_transform.affine_inverse() * state.ball.global_transform
		state.anchors = []
		state.walls = []
		active.append(state)
	_prepare_anchors(active)
	for state in active:
		var ball: MergeBall = state.ball
		_update_release_filter(state,delta)
		for contact in state.contacts:
			var press: Dictionary = state.press_contacts.get(contact.other,{})
			contact.filtered_strength = contact.strength*press.get("weight",1.0)
		var targets := PackedVector2Array()
		var radius := ball.get_radius()
		# Contact keypoints drive only the six shared material controls.
		# Smooth distance weights avoid switching a contact between cage sectors.
		for point: Vector2 in state.rest:
			var offset := Vector2.ZERO
			var total_weight := 0.0
			if not ball.is_ice_frozen:
				for contact in state.contacts:
					if not is_instance_id_valid(contact.other):
						continue
					var normal: Vector2 = contact.direction
					var tangent := Vector2(-normal.y, normal.x)
					var relative: Vector2 = point - contact.position
					var weight := exp(-relative.length_squared() / (radius * radius * 1.44))
					# Pull the broad shoulder toward its contact keypoint's plane,
					# and spread it sideways. No per-render-vertex clipping.
					var displacement := -normal * relative.dot(normal) + tangent * relative.dot(tangent) * 0.8
					offset += displacement * contact.filtered_strength * weight
					total_weight += weight
			var target := (offset / maxf(1.0,total_weight)).limit_length(radius*tuning.maximum_warp)
			# Start release from the last constrained pose, not an unconstrained
			# target or a hard displacement cap. Existing spring integration stays.
			targets.append(target.lerp(state.release_pose[targets.size()],state.release_weight))
		var dt := minf(delta, 1.0 / 30.0) / 2.0
		for substep in 2:
			for i in POINT_COUNT:
				state.velocities[i] += ((targets[i] - state.offsets[i]) * tuning.warp_stiffness - state.velocities[i] * tuning.warp_damping) * dt
				# A contact correction may exceed the normal target amplitude.
				# Clamping that corrected pose here caused a one-frame release snap.
				state.offsets[i] += state.velocities[i] * dt
	for state in active:
		for anchor in state.anchors:
			var press: Dictionary = state.press_contacts.get(anchor.other,{})
			if press.is_empty() or press.weight >= 1.0: continue
			var start := Vector2.ZERO
			for i in POINT_COUNT: start += press.pose[i]*anchor.weights[i]
			anchor.target = anchor.point + start.lerp(anchor.target-anchor.point,press.weight)
	# Evaluate only each precomputed circle contact and its six cage weights.
	for iteration in tuning.contact_passes:
		for state in active:
			for anchor in state.anchors: Constraints.pin(state,anchor)
			for wall in state.walls: Constraints.clip(state,wall)
	for state in active: _clamp_wall_controls(state)
	for state in active:
		_update_sprite_gloss(state)
		for i in POINT_COUNT:
			state.surface_points[i] = state.rest[i] + state.offsets[i]
		var changed: bool = state.visuals.install_pending() or state.published_points.is_empty()
		if not changed:
			for i in POINT_COUNT:
				if state.surface_points[i].distance_squared_to(state.published_points[i]) > 0.0001:
					changed = true
					break
		if changed:
			state.visuals.update_surface(state, tuning)
			state.published_points = state.surface_points.duplicate()

func restore_balls() -> void:
	for state in states.values():
		if is_instance_valid(state.ball):
			if state.ball.contact_observer == state.observer:
				state.ball.contact_observer = state.previous_observer
			state.visuals.restore()
			if is_instance_valid(state.get("gloss")):
				state.gloss.queue_free()
	states.clear()
	contact_shares.clear()

func _binding(state: Dictionary,point: Vector2) -> Dictionary:
	var weights := Constraints.bind(point,state.rest)
	var denominator := 0.0
	for weight in weights: denominator += weight*weight
	return {"point":point,"weights":weights,"denominator":maxf(denominator,0.000001)}

func _prepare_anchors(active: Array) -> void:
	contact_generation += 1
	var bounds := game.get_playable_board_bounds()
	var contacts := {}
	for state in active:
		var center: Vector2 = state.to_board*state.circle_center
		var id: int = state.ball.get_instance_id()
		for contact in state.contacts:
			contacts[str(mini(id,contact.other))+":"+str(maxi(id,contact.other))] = true
		var inverse: Transform2D = state.to_board.affine_inverse()
		for wall in [{"normal":Vector2.LEFT,"distance":-bounds.position.x},
			{"normal":Vector2.RIGHT,"distance":bounds.end.x},
			{"normal":Vector2.UP,"distance":-bounds.position.y},
			{"normal":Vector2.DOWN,"distance":bounds.end.y}]:
			var normal: Vector2 = wall.normal
			if center.dot(normal)+state.radius*(1.0+tuning.maximum_warp)<wall.distance: continue
			var point: Vector2 = state.circle_center+inverse.basis_xform(normal).normalized()*state.radius
			var anchor := _binding(state,point)
			anchor.normal = normal
			anchor.distance = wall.distance-tuning.wall_padding
			state.walls.append(anchor)
	var grid := {}
	var tested := {}
	pair_count = 0
	const CELL := 96.0
	for index in active.size():
		var state: Dictionary = active[index]
		var center: Vector2 = state.to_board*state.circle_center
		var reach: float = state.radius+tuning.contact_lookahead
		var first := Vector2i(((center-Vector2.ONE*reach)/CELL).floor())
		var last := Vector2i(((center+Vector2.ONE*reach)/CELL).floor())
		for x in range(first.x,last.x+1):
			for y in range(first.y,last.y+1):
				var cell := Vector2i(x,y)
				if not grid.has(cell): grid[cell] = []
				for other_index in grid[cell]:
					var key := Vector2i(other_index,index)
					if tested.has(key): continue
					tested[key] = true
					_add_circle_contact(active[other_index],state,contacts)
				grid[cell].append(index)

	for key in contact_shares.keys():
		if contact_shares[key].generation != contact_generation: contact_shares.erase(key)

func _add_circle_contact(a: Dictionary,b: Dictionary,contacts: Dictionary) -> void:
	var center_a: Vector2 = a.to_board*a.circle_center
	var center_b: Vector2 = b.to_board*b.circle_center
	var delta := center_b-center_a
	var reach: float = a.radius+b.radius+tuning.contact_lookahead
	if delta.length_squared()>reach*reach: return
	var distance := delta.length()
	var normal := delta/distance if distance>0.00001 else Vector2.RIGHT
	var key := str(mini(a.ball.get_instance_id(),b.ball.get_instance_id()))+":"+str(maxi(a.ball.get_instance_id(),b.ball.get_instance_id()))
	# Separated circles must not be pulled together just by their visual effect.
	if not contacts.has(key) and distance>a.radius+b.radius+0.5: return
	var point_a: Vector2 = center_a+normal*a.radius
	var point_b: Vector2 = center_b-normal*b.radius
	# Share only the existing contact correction; spring shape and timing stay.
	var world_to_board := game.global_transform.affine_inverse()
	var desired := Constraints.impact_share(world_to_board.basis_xform(a.impact_change),world_to_board.basis_xform(b.impact_change),normal)
	var canonical: bool = a.ball.get_instance_id()<b.ball.get_instance_id()
	var desired_canonical: float = desired if canonical else 1.0-desired
	if not contact_shares.has(key): contact_shares[key] = {"share":0.5,"generation":contact_generation}
	var cached: Dictionary = contact_shares[key]
	cached.share = lerpf(cached.share,desired_canonical,0.25)
	cached.generation = contact_generation
	var share: float = cached.share if canonical else 1.0-cached.share
	var target: Vector2 = point_a.lerp(point_b,share)
	var inverse_a: Transform2D = a.to_board.affine_inverse()
	var inverse_b: Transform2D = b.to_board.affine_inverse()
	var anchor_a := _binding(a,inverse_a*point_a)
	var anchor_b := _binding(b,inverse_b*point_b)
	anchor_a.share = share
	anchor_b.share = 1.0-share
	anchor_a.other = b.ball.get_instance_id()
	anchor_b.other = a.ball.get_instance_id()
	anchor_a.target = inverse_a*target
	anchor_b.target = inverse_b*target
	a.anchors.append(anchor_a)
	b.anchors.append(anchor_b)
	pair_count += 1

func _clamp_wall_controls(state: Dictionary) -> void:
	var bounds := game.get_playable_board_bounds().grow(-tuning.wall_padding)
	var inverse: Transform2D = state.to_board.affine_inverse()
	for i in POINT_COUNT:
		var point: Vector2 = state.to_board*(state.rest[i]+state.offsets[i])
		var clamped := point.clamp(bounds.position,bounds.end)
		if point!=clamped:
			state.offsets[i] = inverse*clamped-state.rest[i]
			state.velocities[i] = Vector2.ZERO

func _update_release_filter(state: Dictionary,delta: float) -> void:
	var touching := {}
	for contact in state.contacts:
		if is_instance_id_valid(contact.other): touching[contact.other] = true
	for anchor in state.anchors: touching[anchor.other] = true
	var released := false
	for id in state.touching:
		if not touching.has(id):
			released = true
			break
	if released:
		state.release_pose = state.offsets.duplicate()
		state.release_weight = 1.0
		# Pinning changed positions while spring velocity could keep accumulating.
		# Release from rest rather than ejecting with that obsolete velocity.
		state.velocities.fill(Vector2.ZERO)
	for id in state.press_contacts.keys():
		if not touching.has(id): state.press_contacts.erase(id)
	for id in touching:
		if not state.press_contacts.has(id):
			state.press_contacts[id] = {"age":0.0,"weight":0.0,"pose":state.offsets.duplicate()}
		else:
			var press: Dictionary = state.press_contacts[id]
			press.age = minf(tuning.press_filter_time,press.age+minf(delta,1.0/30.0))
			press.weight = smoothstep(0.0,tuning.press_filter_time,press.age)
	state.touching = touching
	if state.release_weight > 0.0:
		state.release_weight *= exp(-minf(delta,1.0/30.0)/tuning.release_filter_time)
		if state.release_weight < 0.001: state.release_weight = 0.0

func _install_sprite_gloss(state: Dictionary,outline: PackedVector2Array) -> void:
	var direction := Vector2(-0.62,-0.78).normalized()
	var center: Vector2 = state.circle_center
	var distance: float = state.radius
	# Find an authored attachment once; the ellipse itself is never deformed.
	for i in outline.size():
		var a := outline[i]
		var edge := outline[(i+1)%outline.size()]-a
		var determinant := direction.cross(edge)
		if absf(determinant)<0.000001: continue
		var reach := (a-center).cross(edge)/determinant
		var along := (a-center).cross(direction)/determinant
		if reach>0.0 and along>=0.0 and along<=1.0: distance=minf(distance,reach)
	var point: Vector2 = _gloss_attachment(state,center+direction*distance*0.82)
	var sprite := Sprite2D.new()
	sprite.name = "PondSpriteGloss"
	sprite.texture = tuning.sprite_gloss_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.modulate = Color(1,1,1,tuning.sprite_gloss_opacity)
	sprite.z_index = 4
	sprite.set_meta(&"skip_soft_deformation",true)
	state.ball.visual_container.get_child(0).add_child(sprite)
	state.gloss = sprite
	state.gloss_point = point
	state.gloss_weights = Constraints.bind(point,state.rest)
	_update_sprite_gloss(state)

func _update_sprite_gloss(state: Dictionary) -> void:
	var sprite: Sprite2D = state.get("gloss")
	if not is_instance_valid(sprite): return
	sprite.visible = not state.ball.is_ice_frozen and not state.ball.merge_locked
	var point: Vector2 = state.gloss_point+Constraints.offset(state,state.gloss_weights)
	var canvas_scale: float = maxf(0.0001,state.ball.get_global_transform_with_canvas().x.length())
	var width: float = maxf(state.radius*tuning.sprite_gloss_width_ratio,tuning.sprite_gloss_min_screen_width/canvas_scale)
	var scale: float = width/sprite.texture.get_width()
	var local := Transform2D(deg_to_rad(tuning.sprite_gloss_angle_degrees),Vector2.ONE*scale,0.0,point)
	sprite.transform = (sprite.get_parent() as Node2D).global_transform.affine_inverse()*state.ball.global_transform*local

func _gloss_attachment(state: Dictionary,fallback: Vector2) -> Vector2:
	var mask := state.ball.visual_container.get_child(0).get_node_or_null("ShellOutline") as Sprite2D
	if mask==null or mask.texture==null: return fallback
	var rect := mask.get_rect()
	var key := [mask.texture.get_rid(),rect]
	if not gloss_attachment_cache.has(key):
		var image := mask.texture.get_image()
		if image==null: return fallback
		if image.is_compressed(): image.decompress()
		var center := Vector2(image.get_size())*0.5
		var direction := Vector2(-0.62,-0.78).normalized()
		var last := 0.0
		for step in maxi(image.get_width(),image.get_height()):
			var pixel := Vector2i(center+direction*step)
			if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height(): break
			if image.get_pixelv(pixel).a>0.4: last=step
		var uv := (center+direction*last*0.86)/Vector2(image.get_size())
		gloss_attachment_cache[key]=rect.position+rect.size*uv
	return (state.ball.global_transform.affine_inverse()*mask.global_transform)*gloss_attachment_cache[key]
