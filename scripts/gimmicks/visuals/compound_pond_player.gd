extends Node2D
## Opt-in pond player presentation. The Fighter still owns combat and movement.
const Cutout = preload("res://scripts/axolotl_cutout_preview.gd")
const RIG_PATH := "res://assets/characters/axolotl_cutout/rig.json"

var _fighter: Fighter
var _saved_self_modulate := Color.WHITE
var _outline_sprite: Sprite2D
var _outline_material: ShaderMaterial


func configure(fighter: Fighter, size_multiplier := 1.0, white_outline := false) -> void:
	_fighter = fighter
	var sprite := fighter.character_sprite
	_saved_self_modulate = sprite.self_modulate
	var texture := fighter.character_data.sprite
	var image := texture.get_image()
	var used := image.get_used_rect()
	# The lowest 3% of the old drawing identifies both feet, excluding the tail.
	var foot_band := Rect2i(used.position.x, used.end.y - maxi(1, roundi(used.size.y * 0.03)),
		used.size.x, maxi(1, roundi(used.size.y * 0.03)))
	var feet := image.get_region(foot_band).get_used_rect()
	var old_foot := Vector2(foot_band.position + feet.position)
	old_foot.x += feet.size.x * 0.5
	old_foot.y = used.end.y
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	var source_bounds := Rect2()
	var boot_bounds := Rect2()
	for part: Dictionary in rig["parts"]:
		var b: Array = part["bounds"]
		var rect := Rect2(float(b[0]), float(b[1]), float(b[2])-float(b[0]), float(b[3])-float(b[1]))
		source_bounds = rect if source_bounds.size == Vector2.ZERO else source_bounds.merge(rect)
		if str(part["name"]).begins_with("boot"):
			boot_bounds = rect if boot_bounds.size == Vector2.ZERO else boot_bounds.merge(rect)
	var pixel_scale := fighter.character_data.sprite_size / texture.get_size()
	var ratio := used.size.y * pixel_scale.y / source_bounds.size.y * size_multiplier
	var old_anchor := sprite.position + (old_foot - texture.get_size() * 0.5) * pixel_scale
	var new_anchor := Vector2(boot_bounds.get_center().x, boot_bounds.end.y)
	var puppet := Cutout.new()
	puppet.name = "AxolotlCutout"
	puppet.scale = Vector2.ONE * ratio
	puppet.position = old_anchor - new_anchor * ratio
	modulate = fighter.character_data.display_color * fighter.character_data.sprite_modulate
	if white_outline:
		# Composite first: outlining individual parts would draw white joint seams.
		var padding := Vector2(32.0, 32.0)
		var viewport := SubViewport.new()
		viewport.name = "CutoutComposite"
		viewport.size = Vector2i(int(rig["canvas"][0]) + 64, int(rig["canvas"][1]) + 64)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		viewport.gui_disable_input = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var output_position := puppet.position - padding * ratio
		puppet.position = padding
		puppet.scale = Vector2.ONE
		puppet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		viewport.add_child(puppet)
		_outline_sprite = Sprite2D.new()
		_outline_sprite.name = "OutlinedCutout"
		_outline_sprite.centered = false
		_outline_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_outline_sprite.texture = viewport.get_texture()
		_outline_sprite.position = output_position
		_outline_sprite.scale = Vector2.ONE * ratio
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = preload("res://shaders/character_cutout_outline_aa.gdshader")
		_outline_material.set_shader_parameter("outline_color", Color.WHITE)
		_outline_sprite.material = _outline_material
		add_child(_outline_sprite)
		_update_outline_width()
	else:
		add_child(puppet)
	# self_modulate only hides the old image, including temporary cast textures.
	# Fighter modulation/translation still affects the replacement and hit feedback.
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)


func _process(_delta: float) -> void:
	_update_outline_width()


func _update_outline_width() -> void:
	if not is_instance_valid(_outline_sprite) or not is_instance_valid(_fighter):
		return
	var screen_scale := _outline_sprite.get_global_transform_with_canvas().get_scale().abs()
	var average_scale := maxf((screen_scale.x + screen_scale.y) * 0.5, 0.001)
	_outline_material.set_shader_parameter("outline_size", _fighter.character_data.outline_screen_size / average_scale)


func restore() -> void:
	if is_instance_valid(_fighter) and is_instance_valid(_fighter.character_sprite):
		_fighter.character_sprite.self_modulate = _saved_self_modulate
	_fighter = null


func _exit_tree() -> void:
	restore()
