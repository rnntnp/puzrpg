extends Node2D

func _ready() -> void:
	var background := ColorRect.new()
	background.size = Vector2(720, 1280)
	background.color = Color("#26344b")
	background.z_index = -10
	add_child(background)
	var title := Label.new()
	title.position = Vector2(24, 22)
	title.text = "AXOLOTL BALLS / SIMPLE HEADS"
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)
	for index in 11:
		var visual := (load("res://scenes/balls/visuals/ball_visual_%02d.tscn" % (index + 1)) as PackedScene).instantiate() as Node2D
		add_child(visual)
		visual.position = Vector2(120 + (index % 3) * 240, 205 + (index / 3) * 290)
		visual.scale = Vector2.ONE * 0.49
		var label := Label.new()
		label.position = visual.position + Vector2(-12, 112)
		label.text = "%02d" % (index + 1)
		label.add_theme_font_size_override("font_size", 22)
		add_child(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/previews/simple_axolotls/overview.png")
	print("SIMPLE_AXOLOTLS captured 11 centered visuals")
