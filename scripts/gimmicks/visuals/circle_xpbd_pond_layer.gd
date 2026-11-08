extends Node2D
## Stage 62 retains its resource path, but no longer runs an XPBD solver.
## Only MergeBall.visual_container receives a warp. Bodies are never modified.
const WarpMeshes = preload("res://scripts/gimmicks/visuals/rigid_pond_warp_meshes.gd")
const POINT_COUNT := 6
const ControlCage = preload("res://scripts/gimmicks/visuals/pond_control_cage.gd")
const MAX_CONTACTS := 4
var game: MergeGame
var tuning: Resource
var states: Dictionary = {}
var accumulated_time := 0.0

func configure(board: MergeGame, settings: Resource) -> void:
	game = board
	tuning = settings

func _register(ball: MergeBall) -> void:
	var rest: PackedVector2Array = ControlCage.build(ball, POINT_COUNT).rest
	var offsets := PackedVector2Array()
	var velocities := PackedVector2Array()
	for i in POINT_COUNT:
		offsets.append(Vector2.ZERO)
		velocities.append(Vector2.ZERO)
	var meshes := WarpMeshes.new()
	meshes.configure(ball)
	var observer := _capture_contacts.bind(ball.get_instance_id())
	states[ball.get_instance_id()] = {"ball": ball, "rest": rest, "offsets": offsets,
		"velocities": velocities, "contacts": [], "visuals": meshes,
		"previous_observer": ball.contact_observer, "observer": observer,
		"applied": Transform2D.IDENTITY, "surface_points": rest.duplicate(),
		"published_points": PackedVector2Array()}
	ball.contact_observer = observer

func _capture_contacts(body: PhysicsDirectBodyState2D, id: int) -> void:
	if not states.has(id):
		return
	var record: Dictionary = states[id]
	if record.previous_observer.is_valid():
		record.previous_observer.call(body)
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
		var state: Dictionary = states[id]
		if not is_instance_valid(state.ball):
			states.erase(id)
			continue
		var ball: MergeBall = state.ball
		if ball.merge_locked:
			continue
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
					offset += displacement * contact.strength * weight
					total_weight += weight
			targets.append((offset / maxf(1.0, total_weight)).limit_length(radius * tuning.maximum_warp))
		var dt := minf(delta, 1.0 / 30.0) / 2.0
		for substep in 2:
			for i in POINT_COUNT:
				state.velocities[i] += ((targets[i] - state.offsets[i]) * tuning.warp_stiffness - state.velocities[i] * tuning.warp_damping) * dt
				state.offsets[i] = (state.offsets[i] + state.velocities[i] * dt).limit_length(radius * tuning.maximum_warp)
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
	states.clear()
