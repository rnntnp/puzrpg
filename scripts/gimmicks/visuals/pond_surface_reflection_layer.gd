extends Node2D

const ReflectionShader = preload("res://shaders/pond_surface_reflection.gdshader")
const CELL_SIZE := 96.0
const REFLECTION_LIMIT := 8

var game: MergeGame
var tuning: Resource
var records: Dictionary = {}
var last_refresh_msec := 0
var enabled := false
var integrate_with_outline := false


func configure(target: MergeGame, config: Resource, integrate_outline := false) -> void:
	game = target
	tuning = config
	integrate_with_outline = integrate_outline
	enabled = true
	game.ball_dropped.connect(_on_ball_dropped)
	_refresh()
	last_refresh_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not is_instance_valid(game):
		return
	var moving := false
	for child in game.get_active_balls():
		if child is MergeBall and not child.merge_locked and child.linear_velocity.length_squared() > 25.0:
			moving = true
			break
	var rate: float = tuning.moving_reflection_updates_per_second if moving else tuning.reflection_updates_per_second
	var now := Time.get_ticks_msec()
	# Real-time cadence also works while merge hit-stop slows the physics clock.
	if float(now - last_refresh_msec) < 1000.0 / maxf(1.0, rate):
		return
	last_refresh_msec = now
	_refresh()


func _on_ball_dropped() -> void:
	# Spawn/queue updates must finish before installing the new ball's mesh.
	_refresh.call_deferred()


func _refresh() -> void:
	if not enabled or not is_instance_valid(game):
		return
	var balls: Array[MergeBall] = []
	for child in game.get_active_balls():
		if child is MergeBall and not child.is_queued_for_deletion() and not child.merge_locked:
			balls.append(child)
	if is_instance_valid(game.preview_ball):
		balls.append(game.preview_ball)
	var present: Dictionary = {}
	# Index the published poses. The solver grid uses predicted poses and rebuilds
	# per substep, while reflection queries run against the visible board.
	var grid: Dictionary = {}
	var centers := PackedVector2Array()
	var radii := PackedFloat32Array()
	var max_radius := 0.0
	for ball in balls:
		var center := ball.global_position
		var radius := ball.get_radius()
		var index := centers.size()
		centers.append(center)
		radii.append(radius)
		if ball == game.preview_ball:
			continue
		max_radius = maxf(max_radius, radius)
		var cell := _cell(center)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(index)
	for ball_index in balls.size():
		var ball := balls[ball_index]
		var id := ball.get_instance_id()
		present[id] = true
		if not records.has(id):
			_install(ball)
		if not records.has(id):
			continue
		var record: Dictionary = records[id]
		var surface: Node2D = record.surface
		if not record.integrated:
			surface.visible = not ball.is_ice_frozen
		var material := surface.material as ShaderMaterial
		var center: Vector2 = surface.to_local(ball.global_position)
		var light: Vector2 = surface.to_local(ball.global_position + Vector2(-0.6, -0.8)) - center
		material.set_shader_parameter("light_direction", light.normalized())
		for index in range(3):
			var direction := Vector3(0.0, -1.0, 0.25)
			var color := Color(0.0, 0.0, 0.0, 0.0)
			if index < tuning.environment_light_directions.size():
				direction = tuning.environment_light_directions[index]
			if index < tuning.environment_light_colors.size():
				color = tuning.environment_light_colors[index]
			# Normals are stored in the mesh's local frame, including mask rotation.
			var local_xy: Vector2 = (surface.to_local(ball.global_position + Vector2(direction.x, direction.y)) - surface.to_local(ball.global_position)).normalized()
			material.set_shader_parameter("ambient_direction_%d" % index, Vector3(local_xy.x, local_xy.y, direction.z).normalized())
			material.set_shader_parameter("ambient_color_%d" % index, color)
		var nearest := _find_reflectors(ball_index, grid, centers, radii, max_radius)
		for index in REFLECTION_LIMIT:
			var color := Color(0.0, 0.0, 0.0, 0.0)
			var direction := Vector2.RIGHT
			var sharpness := 12.0
			if index < nearest.size():
				var other: MergeBall = balls[nearest[index].index]
				color = other.visual_container.get_child(0).tint_color
				var cosine_angle: float = nearest[index].cosine
				# Solid angle (apart from 2*PI), plus a smooth finite-range cutoff.
				color.a = nearest[index].weight
				# SG half-maximum matches the apparent angular radius; roughness
				# broadens it slightly. This is an artistic approximation, not GI.
				sharpness = clampf(log(2.0) / maxf(0.001, 1.0 - cosine_angle + tuning.reflection_roughness * tuning.reflection_roughness), 2.0, 128.0)
				direction = (surface.to_local(other.global_position) - center).normalized()
			material.set_shader_parameter("direction_%d" % index, direction)
			material.set_shader_parameter("color_%d" % index, color)
			material.set_shader_parameter("sharpness_%d" % index, sharpness)
	for id in records.keys():
		if not present.has(id):
			_restore(records[id])
			records.erase(id)


func _cell(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL_SIZE).floor())


func _find_reflectors(ball_index: int, grid: Dictionary, centers: PackedVector2Array, radii: PackedFloat32Array, max_radius: float) -> Array[Dictionary]:
	var nearest: Array[Dictionary] = []
	var center := centers[ball_index]
	var radius := radii[ball_index]
	var reach: float = tuning.reflection_reach
	var extent := Vector2.ONE * (radius + max_radius + reach)
	var first := _cell(center - extent)
	var last := _cell(center + extent)
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for other_index: int in grid.get(Vector2i(x, y), []):
				if other_index == ball_index:
					continue
				var other_radius := radii[other_index]
				var limit := radius + other_radius + reach
				var distance_squared := center.distance_squared_to(centers[other_index])
				if distance_squared >= limit * limit:
					continue
				var distance := sqrt(distance_squared)
				var gap := maxf(0.0, distance - radius - other_radius)
				var sine := clampf(other_radius / maxf(distance, other_radius + 0.001), 0.0, 0.999)
				var cosine := sqrt(1.0 - sine * sine)
				var weight := clampf(8.0 * (1.0 - cosine), 0.0, 1.0) * (1.0 - smoothstep(reach * 0.65, reach, gap))
				var insertion := nearest.size()
				while insertion > 0:
					var previous := nearest[insertion - 1]
					if weight <= previous.weight and not (is_equal_approx(weight, previous.weight) and gap < previous.gap):
						break
					insertion -= 1
				if insertion < REFLECTION_LIMIT:
					nearest.insert(insertion, {"index": other_index, "gap": gap, "weight": weight, "cosine": cosine})
					if nearest.size() > REFLECTION_LIMIT:
						nearest.pop_back()
	return nearest


func _install(ball: MergeBall) -> void:
	if ball.visual_container.get_child_count() == 0:
		return
	var visual := ball.visual_container.get_child(0) as Node2D
	var mask := visual.get_node_or_null("ShellOutline") as Sprite2D
	var gloss := visual.get_node_or_null("ShellGloss") as Sprite2D
	if mask == null or mask.texture == null:
		return
	var normal_texture := load("res://resources/visuals/pond_meshes/normal_%02d.res" % (ball.merge_level + 1)) as Texture2D
	if normal_texture == null:
		return
	var outline_material := mask.material as ShaderMaterial
	var integrated := integrate_with_outline and outline_material != null
	var surface: Node2D = mask
	var material := outline_material
	if integrated:
		material.set_shader_parameter("pond_reflection_enabled", true)
	else:
		var mesh := load("res://resources/visuals/pond_meshes/ball_%02d.res" % (ball.merge_level + 1)) as ArrayMesh
		if mesh == null:
			return
		var overlay := MeshInstance2D.new()
		overlay.name = "PondSurfaceReflection"
		overlay.mesh = mesh
		overlay.texture = mask.texture
		overlay.transform = mask.transform
		overlay.z_index = 2
		material = ShaderMaterial.new()
		material.shader = ReflectionShader
		overlay.material = material
		visual.add_child(overlay)
		surface = overlay
	material.set_shader_parameter("surface_normal_texture", normal_texture)
	material.set_shader_parameter("environment_color", tuning.environment_color)
	material.set_shader_parameter("environment_strength", tuning.environment_strength)
	material.set_shader_parameter("highlight_strength", tuning.highlight_strength)
	var highlight_size_scale: float = tuning.stage_8_highlight_size_scale if ball.merge_level == 7 else 1.0
	material.set_shader_parameter("highlight_radius", deg_to_rad(tuning.highlight_radius_degrees) * highlight_size_scale)
	material.set_shader_parameter("highlight_edge", deg_to_rad(tuning.highlight_edge_degrees))
	material.set_shader_parameter("secondary_highlight_strength", tuning.secondary_highlight_strength)
	material.set_shader_parameter("secondary_highlight_radius", deg_to_rad(tuning.secondary_highlight_radius_degrees) * highlight_size_scale)
	material.set_shader_parameter("secondary_highlight_angle", deg_to_rad(tuning.secondary_highlight_angle_degrees))
	material.set_shader_parameter("reflection_strength", tuning.reflection_strength)
	material.set_shader_parameter("reflection_exposure", tuning.reflection_exposure)
	material.set_shader_parameter("reflection_opacity_limit", tuning.reflection_opacity_limit)
	material.set_shader_parameter("reflection_total_opacity_limit", tuning.reflection_total_opacity_limit)
	material.set_shader_parameter("reflection_color_brightness", tuning.reflection_color_brightness)
	records[ball.get_instance_id()] = {"surface": surface, "integrated": integrated, "gloss": gloss, "gloss_visible": gloss.visible if gloss != null else false}
	if gloss != null:
		gloss.hide()


func _restore(record: Dictionary) -> void:
	if is_instance_valid(record.gloss):
		record.gloss.visible = record.gloss_visible
	if is_instance_valid(record.surface):
		if record.integrated:
			(record.surface.material as ShaderMaterial).set_shader_parameter("pond_reflection_enabled", false)
		else:
			record.surface.queue_free()


func restore_visuals() -> void:
	enabled = false
	set_process(false)
	if is_instance_valid(game) and game.ball_dropped.is_connected(_on_ball_dropped):
		game.ball_dropped.disconnect(_on_ball_dropped)
	for record in records.values():
		_restore(record)
	records.clear()


func _exit_tree() -> void:
	restore_visuals()
