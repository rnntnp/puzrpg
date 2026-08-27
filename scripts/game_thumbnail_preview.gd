@tool
extends Control

@export var well_center := Vector2(640.0, 405.0):
	set(value):
		well_center = value
		queue_redraw()
@export var well_width := 500.0:
	set(value):
		well_width = value
		queue_redraw()
@export var well_height := 245.0:
	set(value):
		well_height = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(
		well_center - Vector2(well_width * 0.5, well_height * 0.5),
		Vector2(well_width, well_height)
	)
	var opening := Rect2(
		Vector2(outer.position.x + 28.0, outer.position.y - 24.0),
		Vector2(outer.size.x - 56.0, 118.0)
	)

	# The well is intentionally simple: it is only a framing prop for the real balls.
	draw_style_box(_well_body_style(), outer)
	draw_style_box(_well_opening_style(), opening)

	var block_color := Color("#6f73a5")
	var block_shadow := Color("#353c70")
	for row in 3:
		var y := outer.position.y + 76.0 + row * 52.0
		var offset := 34.0 if row % 2 == 1 else 0.0
		for column in 7:
			var x := outer.position.x + 15.0 + offset + column * 70.0
			var block := Rect2(Vector2(x, y), Vector2(62.0, 43.0))
			if block.end.x > outer.end.x - 8.0:
				continue
			draw_rect(block, block_shadow, true)
			draw_rect(block.grow(-4.0), block_color.lightened(0.08 * row), true)

	# A thick front lip makes the balls read as spilling over the rim.
	var front_lip := Rect2(
		Vector2(opening.position.x - 10.0, opening.position.y + 62.0),
		Vector2(opening.size.x + 20.0, 72.0)
	)
	draw_style_box(_well_lip_style(), front_lip)


func _well_body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#4f568b")
	style.border_color = Color("#17264f")
	style.set_border_width_all(8)
	style.corner_radius_top_left = 72
	style.corner_radius_top_right = 72
	style.corner_radius_bottom_left = 42
	style.corner_radius_bottom_right = 42
	return style


func _well_opening_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111f4d")
	style.border_color = Color("#9296c5")
	style.set_border_width_all(18)
	style.corner_radius_top_left = 70
	style.corner_radius_top_right = 70
	style.corner_radius_bottom_left = 70
	style.corner_radius_bottom_right = 70
	return style


func _well_lip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#777bad")
	style.border_color = Color("#17264f")
	style.set_border_width_all(8)
	style.corner_radius_top_left = 42
	style.corner_radius_top_right = 42
	style.corner_radius_bottom_left = 42
	style.corner_radius_bottom_right = 42
	return style
