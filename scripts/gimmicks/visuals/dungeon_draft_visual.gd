extends Node2D

signal card_selected(card: int)

const Config = preload("res://scripts/gimmicks/configs/dungeon_draft_config.gd")
var canvas: CanvasLayer
var root: Control
var modal: ColorRect
var build_label: Label
var effects: Array[Tween] = []

func _ready() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 45
	add_child(canvas)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	build_label = Label.new()
	build_label.position = Vector2(125, 447)
	build_label.size = Vector2(570, 38)
	build_label.add_theme_font_size_override("font_size", 18)
	build_label.add_theme_color_override("font_color", Color("ffe9a8"))
	build_label.add_theme_color_override("font_outline_color", Color("20162e"))
	build_label.add_theme_constant_override("outline_size", 5)
	build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(build_label)
	modal = ColorRect.new()
	modal.color = Color(0.035, 0.025, 0.08, 0.94)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.hide()
	root.add_child(modal)

func update_build(ranks: Array[int], lightning_hits: int, tuning: Resource) -> void:
	var parts: PackedStringArray = []
	for card in range(ranks.size()):
		if ranks[card] > 0:
			parts.append("%s %d" % [Config.CARD_NAMES[card], ranks[card]])
	build_label.text = "  ·  ".join(parts) if not parts.is_empty() else "웨이브 클리어 → 카드 3장 중 1장 선택"
	if ranks[2] > 0:
		build_label.text += "  ⚡ %d/%d" % [lightning_hits, tuning.lightning_hit_interval]

func show_choices(cards: Array[int], ranks: Array[int], tuning: Resource, cleared: int, total: int) -> void:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	_label(column, "WAVE %d CLEAR" % cleared, 40, Color("ffdf8c"))
	_label(column, "카드 한 장을 선택하세요", 30, Color.WHITE)
	_label(column, "다음 웨이브 %d / %d · 보드와 카드는 그대로 이어집니다\n선택하는 동안 전투가 멈춥니다" % [cleared + 1, total], 20, Color("c8bfdc"))
	var first: Button
	for card in cards:
		var rank := ranks[card] + 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(620, 156)
		button.text = "%s   Lv.%d  %s\n\n%s" % [Config.CARD_NAMES[card], rank, "UPGRADE" if ranks[card] > 0 else "NEW", tuning.card_description(card, rank)]
		button.add_theme_font_size_override("font_size", 23)
		button.add_theme_color_override("font_color", Color("fff4e4"))
		button.add_theme_stylebox_override("normal", _card_style(Config.CARD_COLORS[card], false))
		button.add_theme_stylebox_override("hover", _card_style(Config.CARD_COLORS[card], true))
		button.add_theme_stylebox_override("focus", _card_style(Config.CARD_COLORS[card], true))
		button.add_theme_stylebox_override("pressed", _card_style(Color.WHITE, true))
		button.pressed.connect(_choose.bind(card))
		column.add_child(button)
		if first == null:
			first = button
	_label(column, "같은 카드는 최대 Lv.%d · 효과는 이번 도전에서만 유지" % tuning.maximum_rank, 19, Color("a99abc"))
	var owned: PackedStringArray = []
	for card in range(ranks.size()):
		if ranks[card] > 0:
			owned.append("%s %d" % [Config.CARD_NAMES[card], ranks[card]])
	_label(column, "보유: " + (" · ".join(owned) if not owned.is_empty() else "없음"), 19, Color("ffe9a8"))
	modal.show()
	if first != null:
		first.grab_focus()

func _choose(card: int) -> void:
	if modal.visible:
		card_selected.emit(card)

func hide_choices() -> void:
	modal.hide()
	for button in modal.find_children("*", "Button", true, false):
		button.release_focus()

func _label(parent: Node, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("332943") if highlighted else Color("201b32")
	style.border_color = accent
	style.set_border_width_all(3 if highlighted else 2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func show_hit(target: Vector2, critical: bool, lightning: int, ricochet: int, blocked: bool) -> void:
	var captions: PackedStringArray = []
	if critical:
		captions.append("CRITICAL!")
	if lightning > 0:
		captions.append("번개 +%d" % lightning)
		_line(PackedVector2Array([target + Vector2(0, -155), target + Vector2(-28, -100), target + Vector2(16, -94), target + Vector2(-15, -40), target]), Color("86ddff"))
	if ricochet > 0:
		captions.append("도탄 +%d" % ricochet)
		_line(PackedVector2Array([target, target + Vector2(70, -72), target + Vector2(95, -10), target + Vector2(20, 20), target]), Color("d1a0ff"))
	if blocked:
		captions.append("갑옷")
	if captions.is_empty():
		return
	var label := Label.new()
	label.text = "\n".join(captions)
	label.position = target + Vector2(-100, -125)
	label.size.x = 200
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("ffe9a8"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
	_track(tween)

func _line(points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = 6.0
	line.default_color = color
	line.antialiased = true
	root.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.35)
	tween.tween_callback(line.queue_free)
	_track(tween)

func _track(tween: Tween) -> void:
	for index in range(effects.size() - 1, -1, -1):
		if not effects[index].is_valid():
			effects.remove_at(index)
	effects.append(tween)

func _exit_tree() -> void:
	for tween in effects:
		if tween.is_valid():
			tween.kill()
	effects.clear()
