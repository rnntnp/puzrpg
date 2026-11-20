extends Node2D

signal layout_selected(index: int)

var info_layer := Node2D.new()
var opaque_bounds: Dictionary = {}

const FighterScene = preload("res://scenes/fighter.tscn")
const HealthBarScene = preload("res://scenes/water_health_bar.tscn")
const HEALTH_BAR_SCALE := 0.20


func _ready() -> void:
	info_layer.z_index = 200
	add_child(info_layer)


func spawn(character: CharacterData, health: int, attack: int, at: Vector2, size_factor: float) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	var stats := character.duplicate() as CharacterData
	stats.max_health = maxi(1, health)
	stats.attack_power = attack
	fighter.character_data = stats
	var anchor := Node2D.new()
	anchor.position = at
	fighter.scale = Vector2.ONE * size_factor
	anchor.add_child(fighter)
	add_child(anchor)
	_add_health_bar(fighter)
	return fighter


func add_layout_buttons(layout_names: PackedStringArray) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(381, 110)
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	var group := ButtonGroup.new()
	for index in range(layout_names.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(33 if layout_names.size() > 6 else 46, 46)
		button.text = str(index + 1)
		button.tooltip_text = layout_names[index]
		button.add_theme_font_size_override("font_size", 22)
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(index == 0)
		button.pressed.connect(func() -> void: layout_selected.emit(index))
		row.add_child(button)


func _sprite_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2(-0.5, -0.5, 1.0, 1.0)
	if not opaque_bounds.has(texture):
		var image := texture.get_image()
		var bounds := Rect2(-0.5, -0.5, 1.0, 1.0)
		if image != null and not image.is_empty():
			var used := image.get_used_rect()
			if used.has_area():
				var image_size := Vector2(image.get_size())
				bounds = Rect2(Vector2(used.position) / image_size - Vector2.ONE * 0.5, Vector2(used.size) / image_size)
		opaque_bounds[texture] = bounds
	return opaque_bounds[texture]


func sprite_span(character: CharacterData, size_factor: float) -> Vector2:
	if character.sprite == null:
		return Vector2(-55, 55) * size_factor
	var bounds := _sprite_bounds(character.sprite)
	var span := Vector2(bounds.position.x, bounds.end.x)
	if character.sprite_flip_h:
		span = Vector2(-span.y, -span.x)
	return (span * character.sprite_size.x + Vector2.ONE * character.sprite_horizontal_offset) * size_factor


func _add_health_bar(fighter: Fighter) -> void:
	var bar := HealthBarScene.instantiate() as WaterHealthBar
	bar.fill_color = Color(0.72, 0.22, 0.88, 1)
	bar.scale = Vector2.ONE * HEALTH_BAR_SCALE
	info_layer.add_child(bar)
	bar.value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.value_label.add_theme_font_size_override("font_size", 52)
	bar.value_label.add_theme_constant_override("outline_size", 12)
	bar.value_label.position.y = -39.0
	bar.value_label_background.hide()
	bar.set_health(fighter.current_health, fighter.max_health)
	fighter.set_meta("formation_info", bar)
	fighter.health_changed.connect(bar.set_health)
	fighter.tree_exiting.connect(bar.queue_free)


func position_info(fighter: Fighter, slot_position: Vector2, offset: Vector2) -> void:
	var bar: WaterHealthBar = fighter.get_meta("formation_info")
	var character := fighter.character_data
	var size_factor := fighter.base_scale.x
	var span := sprite_span(character, size_factor)
	var top := -75.0
	if character.sprite != null:
		top = _sprite_bounds(character.sprite).position.y * character.sprite_size.y + character.sprite_height_offset
	var head := slot_position + Vector2((span.x + span.y) * 0.5, top * size_factor)
	bar.position = head + offset - Vector2(bar.size.x * 0.5, 73.0) * HEALTH_BAR_SCALE
