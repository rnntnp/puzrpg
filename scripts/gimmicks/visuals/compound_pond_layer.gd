extends "res://scripts/gimmicks/visuals/circle_xpbd_pond_layer.gd"
## Stage 63 keeps stage 62's six controls, four visual contact directions,
## body-level filters, springs and wall-control clamp. Only anchor positions
## use installed compound/enlarged shapes. Physical collision setup is separate.
const ShapeDistance = preload("res://scripts/gimmicks/visuals/compound_pond_shape_distance.gd")
var colliders: RefCounted

func _register(ball: MergeBall) -> void:
	colliders.install(ball, tuning)
	super._register(ball)
	var shapes := []
	for child in ball.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			shapes.append(child)
	states[ball.get_instance_id()].shapes = shapes
	states[ball.get_instance_id()].observed_contacts = []
	states[ball.get_instance_id()].contact_memory = {}

func _physics_process(delta: float) -> void:
	colliders.prune()
	super._physics_process(delta)

func _capture_contacts(body: PhysicsDirectBodyState2D, id: int) -> void:
	# Reuse 62's response measurement. Seed body-level history from all native
	# reports, independently of the strongest-four visual direction budget.
	super._capture_contacts(body, id)
	if not states.has(id): return
	var observed := []
	for i in body.get_contact_count():
		var other := body.get_contact_collider_object(i) as PhysicsBody2D
		if not is_instance_valid(other): continue
		var normal := body.get_contact_local_normal(i)
		var relative := body.get_contact_local_velocity_at_position(i) - body.get_contact_collider_velocity_at_position(i)
		var speed := maxf(absf(relative.dot(normal)), body.get_contact_impulse(i).length() * body.inverse_mass)
		observed.append({"other":other.get_instance_id(), "other_body":other,
			"direction":-body.transform.basis_xform_inv(normal).normalized(),
			"strength":tuning.resting_squash + tuning.impact_squash * clampf(speed/tuning.impact_speed, 0.0, 1.0)})
	states[id].observed_contacts = observed

func _body_shapes(body: PhysicsBody2D) -> Array:
	var result := []
	for child in body.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _measure_pair(ball: MergeBall, other: PhysicsBody2D, direction: Vector2) -> Dictionary:
	var to_board := game.global_transform.affine_inverse()
	var best := {}
	var gap := INF
	for a: CollisionShape2D in states[ball.get_instance_id()].shapes:
		if not is_instance_valid(a) or a.disabled or a.is_queued_for_deletion(): continue
		for b: CollisionShape2D in _body_shapes(other):
			var result := ShapeDistance.measure(a.shape, to_board*a.global_transform, b.shape, to_board*b.global_transform, direction)
			if result.gap < gap:
				gap = result.gap
				best = result
	return best

func _retain_contacts(active: Array) -> void:
	for state in active:
		var memory: Dictionary = state.contact_memory
		var observed := {}
		for contact in state.observed_contacts:
			if not observed.has(contact.other) or observed[contact.other].strength < contact.strength:
				observed[contact.other] = contact
		for id in observed: memory[id] = observed[id].duplicate()
		var maintained := []
		for id in memory.keys():
			var contact: Dictionary = memory[id]
			var other = contact.other_body
			if not is_instance_valid(other) or other.is_queued_for_deletion():
				memory.erase(id)
				continue
			if other is MergeBall and (other.merge_locked or not states.has(id)):
				memory.erase(id)
				continue
			var normal: Vector2 = state.to_board.basis_xform(contact.direction).normalized()
			var geometry := _measure_pair(state.ball, other, normal)
			# History never outlives actual collider proximity. No grace timer or
			# enclosing-circle test can glue separated bodies together.
			if geometry.is_empty() or geometry.gap > tuning.contact_release_gap:
				memory.erase(id)
				continue
			contact.direction = state.to_board.basis_xform_inv(geometry.normal).normalized()
			contact.position = state.to_board.affine_inverse() * geometry.a
			contact.board_other_point = geometry.b
			if not observed.has(id): contact.strength = tuning.resting_squash
			maintained.append(contact)
		maintained.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.strength > b.strength)
		state.maintained_contacts = maintained
		state.contacts = maintained.slice(0, MAX_CONTACTS)

func _update_release_filter(state: Dictionary, delta: float) -> void:
	# Touch identity uses all geometrically maintained neighbors, while spring
	# forcing retains 62's strongest-four visual budget. Times/formulas unchanged.
	var selected: Array = state.contacts
	state.contacts = state.maintained_contacts
	super._update_release_filter(state, delta)
	state.contacts = selected

func _support(node: CollisionShape2D, direction: Vector2, hint := Vector2(INF, INF)) -> Vector2:
	var local_direction := node.transform.basis_xform_inv(direction).normalized()
	var point := Vector2.ZERO
	if node.shape is CircleShape2D:
		point = local_direction * node.shape.radius
	elif node.shape is CapsuleShape2D:
		point = local_direction * node.shape.radius
		point.y += signf(local_direction.y) * maxf(0.0, node.shape.height * 0.5 - node.shape.radius)
	elif node.shape is ConvexPolygonShape2D:
		var score := -INF
		for candidate in node.shape.points:
			score = maxf(score, candidate.dot(local_direction))
		var face := PackedVector2Array()
		for candidate in node.shape.points:
			if score - candidate.dot(local_direction) < 0.001: face.append(candidate)
		point = face[0]
		if face.size() > 1:
			# A flat face has many equally valid support points. Preserve the
			# physical contact along it instead of selecting an arbitrary end.
			point = (face[0] + face[-1]) * 0.5 if is_inf(hint.x) else Geometry2D.get_closest_point_to_segment(node.transform.affine_inverse() * hint, face[0], face[-1])
	else:
		var rect := node.shape.get_rect()
		point = rect.get_center() + rect.size * 0.5 * local_direction.sign()
	return node.transform * point

func _prepare_anchors(active: Array) -> void:
	contact_generation += 1
	pair_count = 0
	var bounds := game.get_playable_board_bounds()
	var tested := {}
	_retain_contacts(active)
	for state in active:
		var inverse: Transform2D = state.to_board.affine_inverse()
		# One keypoint per wall, as in 62; only its position comes from the
		# installed shape union instead of the enclosing radius.
		for wall in [{"normal":Vector2.LEFT,"distance":-bounds.position.x},
			{"normal":Vector2.RIGHT,"distance":bounds.end.x},
			{"normal":Vector2.UP,"distance":-bounds.position.y},
			{"normal":Vector2.DOWN,"distance":bounds.end.y}]:
			var normal: Vector2 = wall.normal
			var point := Vector2.ZERO
			var furthest := -INF
			for node: CollisionShape2D in state.shapes:
				if not is_instance_valid(node) or node.disabled: continue
				var candidate := _support(node, inverse.basis_xform(normal).normalized())
				var distance: float = (state.to_board * candidate).dot(normal)
				if distance > furthest:
					furthest = distance
					point = candidate
			if furthest < wall.distance - state.radius * tuning.maximum_warp: continue
			var anchor := _binding(state, point)
			anchor.normal = normal
			anchor.distance = wall.distance - tuning.wall_padding
			state.walls.append(anchor)
		for contact in state.maintained_contacts:
			if not states.has(contact.other): continue
			var other: Dictionary = states[contact.other]
			if not is_instance_valid(other.ball) or other.ball.merge_locked: continue
			var key := "%d:%d" % [mini(state.ball.get_instance_id(), other.ball.get_instance_id()), maxi(state.ball.get_instance_id(), other.ball.get_instance_id())]
			if tested.has(key): continue
			tested[key] = true
			var normal: Vector2 = state.to_board.basis_xform(contact.direction).normalized()
			var inverse_b: Transform2D = other.to_board.affine_inverse()
			var point_a: Vector2 = contact.position
			var point_b: Vector2 = inverse_b * contact.board_other_point
			var board_a: Vector2 = state.to_board * point_a
			var board_b: Vector2 = other.to_board * point_b
			# One anchor pair per neighboring body, preserving 62's filter and
			# impact-share identity when native contact reports flicker.
			var world_to_board := game.global_transform.affine_inverse()
			var desired := Constraints.impact_share(world_to_board.basis_xform(state.impact_change), world_to_board.basis_xform(other.impact_change), normal)
			var canonical: bool = state.ball.get_instance_id() < other.ball.get_instance_id()
			var desired_canonical: float = desired if canonical else 1.0 - desired
			if not contact_shares.has(key): contact_shares[key] = {"share":0.5,"generation":contact_generation}
			var cached: Dictionary = contact_shares[key]
			cached.share = lerpf(cached.share, desired_canonical, 0.25)
			cached.generation = contact_generation
			var share: float = cached.share if canonical else 1.0 - cached.share
			var target := board_a.lerp(board_b, share)
			var anchor_a := _binding(state, point_a)
			var anchor_b := _binding(other, point_b)
			anchor_a.other = other.ball.get_instance_id()
			anchor_b.other = state.ball.get_instance_id()
			anchor_a.target = inverse * target
			anchor_b.target = inverse_b * target
			state.anchors.append(anchor_a)
			other.anchors.append(anchor_b)
			pair_count += 1
	for key in contact_shares.keys():
		if contact_shares[key].generation != contact_generation: contact_shares.erase(key)

func restore_balls() -> void:
	# State-owned geometry histories are discarded together with observers.
	super.restore_balls()

func _exit_tree() -> void:
	restore_balls()
