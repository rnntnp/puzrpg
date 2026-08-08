class_name BallEvolutionStrip
extends Panel

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")

@onready var sequence: HBoxContainer = $Sequence


func _ready() -> void:
	_build_sequence()


func _build_sequence() -> void:
	for child in sequence.get_children():
		child.queue_free()

	for index in BallCatalogClass.BALLS.size():
		if index > 0:
			sequence.add_child(_create_arrow())
		sequence.add_child(_create_ball_icon(BallCatalogClass.get_ball(index)))


func _create_ball_icon(data: Resource) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = data.sprite
	icon.modulate = data.sprite_modulate
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = "%d단계 · 합성 점수 %d" % [data.level, data.merge_score]
	return icon


func _create_arrow() -> Label:
	var arrow := Label.new()
	arrow.custom_minimum_size = Vector2(18, 28)
	arrow.text = "›"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color", Color("#8090a8"))
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return arrow
