extends Node2D

const HealBurst = preload("res://scripts/heal_cross_particle_burst.gd")
const NumberFont = preload("res://assets/fonts/nanum_square_round/NanumSquareRoundEB.ttf")


func add_glow(at: Vector2, diameter: float, tint := Color("#81ff9b")) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(tint, 0.7), Color(tint, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var glow := Sprite2D.new()
	glow.texture = texture
	glow.scale = Vector2.ONE * diameter / float(texture.get_width())
	glow.modulate.a = 0.0
	add_child(glow)
	glow.global_position = at
	return glow


func show_recovery(at: Vector2, amount: int, play_chime: bool) -> void:
	var burst := HealBurst.new()
	add_child(burst)
	burst.play(at, play_chime)
	var number := Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.text = "+%d" % amount
	number.add_theme_font_override("font", NumberFont)
	number.add_theme_font_size_override("font_size", 32)
	number.add_theme_color_override("font_color", Color("#a1ffae"))
	number.add_theme_color_override("font_outline_color", Color("#143b29"))
	number.add_theme_constant_override("outline_size", 7)
	add_child(number)
	number.reset_size()
	number.global_position = at - Vector2(number.size.x * 0.5, 44.0)
	var tween := number.create_tween().set_ignore_time_scale(true).set_parallel()
	tween.tween_property(number, "position:y", number.position.y - 35.0, 0.62)
	tween.tween_property(number, "modulate:a", 0.0, 0.25).set_delay(0.37)
	tween.chain().tween_callback(number.queue_free)
