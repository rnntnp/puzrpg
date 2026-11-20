extends RefCounted
## Installs/restores stage-owned shapes without mutating BallData or visual scenes.
var records: Dictionary = {}

func install(ball: MergeBall, config: Resource) -> void:
	var id := ball.get_instance_id()
	if records.has(id) and records[id].stage == ball.merge_level: return
	if records.has(id): _restore(records[id], false)
	var profile: PackedVector2Array = config.polygon_profiles.for_stage(ball.merge_level + 1)
	var mask := ball.visual_container.get_child(0).get_node_or_null("ShellOutline") as Sprite2D
	if mask == null: return
	var saved := []
	for child in ball.get_children():
		if child is CollisionShape2D:
			saved.append({"node":child, "disabled":child.disabled})
			child.disabled = true
	var added := []
	var to_body := ball.global_transform.affine_inverse() * mask.global_transform
	var extent := 0.0
	var size_scale: float = config.collider_size_scale
	if not profile.is_empty():
		var node := CollisionShape2D.new()
		node.name = "PondConvexSilhouette"
		var shape := ConvexPolygonShape2D.new()
		var points := PackedVector2Array()
		for point in profile:
			points.append((to_body * point) * size_scale)
		shape.points = points
		node.shape = shape
		ball.add_child(node)
		added.append(node)
		extent = ball._get_shape_extent(node)
	# Other stages retain their original shape composition, baked into private
	# copies at the same uniform size increase. Never scale the artwork/body.
	if profile.is_empty():
		for original in saved:
			if original.disabled or original.node.is_queued_for_deletion(): continue
			var node := CollisionShape2D.new()
			node.name = "PondExpandedHitbox%d" % added.size()
			if not ball._assign_baked_shape(node, original.node.shape, original.node.transform, size_scale):
				node.free()
				continue
			ball.add_child(node)
			added.append(node)
			extent = maxf(extent, ball._get_shape_extent(node))
	records[id] = {"ball":ball, "stage":ball.merge_level, "saved":saved, "added":added,
		"radius":ball._hitbox_radius, "contacts":ball.max_contacts_reported, "inertia":ball.inertia}
	ball._hitbox_radius = extent
	ball.max_contacts_reported = config.compound_max_contacts
	# Recompute the body's natural compound inertia rather than retaining a cache.
	ball.inertia = 0.0

func restore() -> void:
	for record in records.values(): _restore(record)
	records.clear()

func prune() -> void:
	for id in records.keys():
		if not is_instance_valid(records[id].ball): records.erase(id)

func _restore(record: Dictionary, restore_body := true) -> void:
	if not is_instance_valid(record.ball): return
	if restore_body:
		for saved in record.saved:
			if is_instance_valid(saved.node): saved.node.disabled = saved.disabled
	for node in record.added:
		if is_instance_valid(node):
			node.disabled = true
			node.queue_free()
	if restore_body:
		record.ball._hitbox_radius = record.radius
		record.ball.max_contacts_reported = record.contacts
	record.ball.inertia = record.inertia if restore_body else 0.0
