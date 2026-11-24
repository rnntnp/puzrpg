extends RefCounted
## Bounded GPU jump-flood distance field, shared by all visible balls.
## Ownership supplies the inside/outside sign; only the visible inside draws.
const FieldShader = preload("res://shaders/deformable_pond_sdf.gdshader")
var buffers: Array[SubViewport] = []
var quads: Array[ColorRect] = []

func configure(owner: Node2D) -> void:
	# At 2x resolution, 8+4+2+1 propagates 7.5 screen px, covering the
	# authored 6px stroke plus its antialias fringe without full-screen JFA.
	for index in 5:
		var buffer:=SubViewport.new()
		buffer.name="CutSDFSeed" if index==0 else "CutSDFJump%d"%index
		buffer.world_2d=World2D.new()
		buffer.transparent_bg=true
		buffer.disable_3d=true
		buffer.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		owner.add_child(buffer)
		var quad:=ColorRect.new()
		var material:=ShaderMaterial.new()
		material.shader=FieldShader
		material.set_shader_parameter("ownership",owner.viewport.get_texture())
		material.set_shader_parameter("seed_pass",index==0)
		if index>0:
			material.set_shader_parameter("previous_field",buffers[-1].get_texture())
			material.set_shader_parameter("jump",float(1<<(4-index)))
		quad.material=material
		buffer.add_child(quad)
		buffers.append(buffer)
		quads.append(quad)

func resize(size: Vector2i) -> void:
	for index in buffers.size():
		buffers[index].size=size
		quads[index].size=Vector2(size)

func set_enabled(enabled: bool) -> void:
	for buffer in buffers:
		buffer.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func texture() -> Texture2D:
	return buffers[-1].get_texture()
