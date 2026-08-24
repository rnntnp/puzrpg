class_name BallEvolutionStrip
extends Panel

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const BALL_VISUAL_SOURCE_SIZE := 418.0
const EVOLUTION_TRACK_WIDTH := 40.0

@onready var sequence: VBoxContainer = $Sequence


func _ready() -> void:
	_build_sequence()


func _build_sequence() -> void:
	for child in sequence.get_children():
		child.queue_free()

	var ball_count := BallCatalogClass.BALLS.size()
	for index in ball_count:
		if index > 0:
			sequence.add_child(_create_arrow())
		sequence.add_child(_create_ball_icon(BallCatalogClass.get_ball(index), index, ball_count))


func _create_ball_icon(data: Resource, index: int, ball_count: int) -> Control:
	var size := lerpf(22.0, 40.0, float(index) / float(maxi(1, ball_count - 1)))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(EVOLUTION_TRACK_WIDTH, size)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.tooltip_text = "%d단계 · 합성 점수 %d" % [data.level, data.merge_score]

	var scene: PackedScene = data.visual_scene
	if scene == null:
		return holder
	var visual_holder := Node2D.new()
	visual_holder.position = Vector2(EVOLUTION_TRACK_WIDTH * 0.5, size * 0.5)
	visual_holder.scale = Vector2.ONE * (size / BALL_VISUAL_SOURCE_SIZE)
	holder.add_child(visual_holder)
	visual_holder.add_child(scene.instantiate())
	return holder


func _create_arrow() -> Label:
	var arrow := Label.new()
	arrow.custom_minimum_size = Vector2(26, 8)
	arrow.text = "∨"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0, 0.72))
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return arrow
