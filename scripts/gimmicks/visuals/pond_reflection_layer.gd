extends Node2D

const ReflectionShader = preload("res://shaders/pond_ball_reflection.gdshader")
var game: MergeGame
var tuning: Resource
var records: Dictionary = {}
var last_refresh_msec := 0
var enabled := false


func configure(target: MergeGame, config: Resource) -> void:
	game = target
	tuning = config
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
	# A spatial grid bounds the neighborhood search to nearby cells.
	var grid: Dictionary = {}
	var cell_size: float = tuning.reflection_reach + 360.0
	for ball in balls:
		var cell := Vector2i((ball.global_position / cell_size).floor())
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(ball)
	for ball in balls:
		var id := ball.get_instance_id()
		present[id] = true
		if not records.has(id):
			_install(ball)
		if not records.has(id):
			continue
		var record: Dictionary = records[id]
		var visual: Node2D = record.visual
		var overlay: MeshInstance2D = record.overlay
		overlay.visible = not ball.is_ice_frozen
		var material := overlay.material as ShaderMaterial
		var center: Vector2 = visual.to_local(ball.global_position)
		var light: Vector2 = visual.to_local(ball.global_position + Vector2(-0.6, -0.8)) - center
		material.set_shader_parameter("light_direction", light.normalized())
		for index in range(3):
			var direction := Vector3(0.0, -1.0, 0.25)
			var color := Color(0.0, 0.0, 0.0, 0.0)
			if index < tuning.environment_light_directions.size():
				direction = tuning.environment_light_directions[index]
			if index < tuning.environment_light_colors.size():
				color = tuning.environment_light_colors[index]
			# Normals are stored in the mesh's local frame, including mask rotation.
			var local_xy: Vector2 = (overlay.to_local(ball.global_position + Vector2(direction.x, direction.y)) - overlay.to_local(ball.global_position)).normalized()
			material.set_shader_parameter("ambient_direction_%d" % index, Vector3(local_xy.x, local_xy.y, direction.z).normalized())
			material.set_shader_parameter("ambient_color_%d" % index, color)
		var nearest: Array[Dictionary] = []
		var cell := Vector2i((ball.global_position / cell_size).floor())
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in grid.get(cell + Vector2i(x, y), []):
					if other == ball or other == game.preview_ball:
						continue
					var gap: float = maxf(0.0, ball.global_position.distance_to(other.global_position) - ball.get_radius() - other.get_radius())
					if gap >= tuning.reflection_reach:
						continue
					nearest.append({"ball": other, "gap": gap})
		nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap < b.gap)
		for index in range(3):
			var color := Color(0.0, 0.0, 0.0, 0.0)
			var direction := Vector2.RIGHT
			var sharpness := 12.0
			if index < nearest.size():
				var other: MergeBall = nearest[index].ball
				color = other.ball_data.glow_color
				var distance: float = maxf(ball.global_position.distance_to(other.global_position), other.get_radius() + 0.001)
				var sine_angle: float = clampf(other.get_radius() / distance, 0.0, 0.999)
				var cosine_angle := sqrt(1.0 - sine_angle * sine_angle)
				# Solid angle (apart from 2*PI), plus a smooth finite-range cutoff.
				var range_weight: float = 1.0 - smoothstep(tuning.reflection_reach * 0.65, tuning.reflection_reach, nearest[index].gap)
				color.a = clampf(8.0 * (1.0 - cosine_angle), 0.0, 1.0) * range_weight
				# SG half-maximum matches the apparent angular radius; roughness
				# broadens it slightly. This is an artistic approximation, not GI.
				sharpness = clampf(log(2.0) / maxf(0.001, 1.0 - cosine_angle + tuning.reflection_roughness * tuning.reflection_roughness), 2.0, 128.0)
				direction = (visual.to_local(other.global_position) - center).normalized()
			material.set_shader_parameter("direction_%d" % index, direction)
			material.set_shader_parameter("color_%d" % index, color)
			material.set_shader_parameter("sharpness_%d" % index, sharpness)
	for id in records.keys():
		if not present.has(id):
			_restore(records[id])
			records.erase(id)


func _install(ball: MergeBall) -> void:
	if ball.visual_container.get_child_count() == 0:
		return
	var visual := ball.visual_container.get_child(0) as Node2D
	var mask := visual.get_node_or_null("ShellOutline") as Sprite2D
	var gloss := visual.get_node_or_null("ShellGloss") as Sprite2D
	if mask == null or mask.texture == null:
		return
	# Prebuilt from each stage's sprite alpha; no contour extraction in gameplay.
	var mesh := load("res://resources/visuals/pond_meshes/ball_%02d.res" % (ball.merge_level + 1)) as ArrayMesh
	if mesh == null:
		return
	var overlay := MeshInstance2D.new()
	overlay.name = "PondSurfaceReflection"
	overlay.mesh = mesh
	overlay.texture = mask.texture
	overlay.transform = mask.transform
	overlay.z_index = 2
	var material := ShaderMaterial.new()
	material.shader = ReflectionShader
	material.set_shader_parameter("surface_normal_texture", load("res://resources/visuals/pond_meshes/normal_%02d.res" % (ball.merge_level + 1)))
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
	overlay.material = material
	visual.add_child(overlay)
	records[ball.get_instance_id()] = {"visual": visual, "overlay": overlay, "gloss": gloss, "gloss_visible": gloss.visible if gloss != null else false}
	if gloss != null:
		gloss.hide()


func _restore(record: Dictionary) -> void:
	if is_instance_valid(record.gloss):
		record.gloss.visible = record.gloss_visible
	if is_instance_valid(record.overlay):
		record.overlay.queue_free()


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
