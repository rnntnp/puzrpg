extends SceneTree

const SURFACE_DEPTH_RATIO := 0.18

func _initialize() -> void:
	_generate.call_deferred()


func _generate() -> void:
	var builder = load("res://scripts/gimmicks/visuals/pond_silhouette_mesh.gd")
	DirAccess.make_dir_recursive_absolute("res://resources/visuals/pond_meshes")
	for stage in range(1, 12):
		if "--stage-8-only" in OS.get_cmdline_user_args() and stage != 8:
			continue
		var data = load("res://resources/balls/ball_%02d.tres" % stage)
		var visual = data.visual_scene.instantiate()
		var mask = visual.get_node("ShellOutline") as Sprite2D
		# A shallower dome reaches the highlight's normal angle nearer the rim.
		var depth_ratio := 0.15 if stage == 8 else SURFACE_DEPTH_RATIO
		# Smooth the stage-8 dome, not its authored silhouette or collider.
		var smoothing_passes := 3 if stage == 8 else 0
		var mesh: ArrayMesh = builder.build(mask.texture, depth_ratio, smoothing_passes)
		var normal_map: ImageTexture = builder.normal_texture(mask.texture, depth_ratio, smoothing_passes)
		if ResourceSaver.save(normal_map, "res://resources/visuals/pond_meshes/normal_%02d.res" % stage) != OK:
			quit(1)
			return
		if mesh == null or ResourceSaver.save(mesh, "res://resources/visuals/pond_meshes/ball_%02d.res" % stage) != OK:
			push_error("Could not build pond mesh for stage %d" % stage)
			visual.free()
			quit(1)
			return
		visual.free()
	print("POND_MESHES_GENERATED")
	quit()
