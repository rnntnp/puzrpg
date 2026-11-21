extends PanelContainer

signal close_requested

const FONT = preload("res://assets/fonts/nanum_square_round/NanumSquareRoundEB.ttf")
const ActionIcons = preload("res://scripts/enemy_action_icons.gd")
const WIDTH := 480.0
const MAX_EFFECT_HEIGHT := 252.0

var title_label: Label
var hp_label: Label
var action_icon: TextureRect
var action_label: Label
var action_turns: Label
var action_description: Label
var effects_title: Label
var effects_scroll: ScrollContainer
var effects_list: VBoxContainer
var effect_rows: Array[VBoxContainer] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	z_index = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#15182b")
	style.border_color = Color("#5b5779")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	title_label = _label(header, 25)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(header)
	close.name = "Close"
	close.text = "×"
	close.custom_minimum_size.x = 42
	close.pressed.connect(func() -> void: close_requested.emit())
	var health := HBoxContainer.new()
	health.add_theme_constant_override("separation", 8)
	body.add_child(health)
	var hp_caption := _label(health, 23)
	hp_caption.text = "HP"
	hp_caption.modulate = Color("#a9eba9")
	hp_label = _label(health, 26)
	var action := HBoxContainer.new()
	action.add_theme_constant_override("separation", 8)
	body.add_child(action)
	action_icon = _icon(action, 33)
	action_label = _label(action, 22)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_turns = _turn_label(action)
	action_description = _label(body, 20)
	action_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_title = _label(body, 18)
	effects_title.text = "상태효과"
	effects_scroll = ScrollContainer.new()
	effects_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(effects_scroll)
	effects_list = VBoxContainer.new()
	effects_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_scroll.add_child(effects_list)


func present(enemy: Fighter, kind: int, turns: String, icon: Texture2D, damage: int, demo: bool) -> void:
	match enemy.character_data.display_name:
		"RED":
			title_label.text = "연못 마법사"
		"RED ELITE":
			title_label.text = "정예 연못 마법사"
		_:
			title_label.text = enemy.character_data.display_name
	hp_label.text = "%d / %d" % [enemy.current_health, enemy.max_health]
	var title := "행동 불명" if kind == ActionIcons.Kind.UNKNOWN else ActionIcons.label_for(kind)
	action_label.text = title
	action_turns.text = "%s턴 후" % turns
	action_icon.texture = icon
	match kind:
		ActionIcons.Kind.ATTACK:
			action_description.text = "플레이어에게 %d의 피해를 입힙니다. (보호막 적용 전)" % damage
		ActionIcons.Kind.SKILL:
			action_description.text = "플레이어를 약화시키거나 다른 몬스터들을 강화하는 스킬 중 하나를 사용하려고 합니다." if demo else "스킬을 사용하려고 합니다."
		ActionIcons.Kind.HEAL:
			action_description.text = "자신이나 다른 몬스터의 체력을 회복하려고 합니다."
		_:
			action_description.text = "다음 행동을 알 수 없습니다."


func set_effect(index: int, icon: Texture2D, effect_name: String, duration: String, description: String) -> void:
	while effect_rows.size() <= index:
		_add_effect_row()
	var row := effect_rows[index]
	row.show()
	(row.get_node("Header/Icon") as TextureRect).texture = icon
	(row.get_node("Header/Title") as Label).text = effect_name
	(row.get_node("Header/Turns") as Label).text = duration
	(row.get_node("Description") as Label).text = description


func trim_effects(count: int) -> void:
	for index in range(effect_rows.size()):
		effect_rows[index].visible = index < count
	effects_title.visible = count > 0
	effects_scroll.visible = count > 0
	var target_height := minf(MAX_EFFECT_HEIGHT, effects_list.get_combined_minimum_size().y)
	if not is_equal_approx(effects_scroll.custom_minimum_size.y, target_height):
		effects_scroll.custom_minimum_size.y = target_height
		reset_size()


func reset_scroll() -> void:
	effects_scroll.scroll_vertical = 0


func _add_effect_row() -> void:
	var row := VBoxContainer.new()
	effects_list.add_child(row)
	effect_rows.append(row)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	row.add_child(header)
	var icon := _icon(header, 24)
	icon.name = "Icon"
	var label := _label(header, 22)
	label.name = "Title"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label(header).name = "Turns"
	var description := _label(row, 20)
	description.name = "Description"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color("#d8d2ed")


func _turn_label(parent: Control) -> Label:
	var label := _label(parent, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.modulate = Color("#d8dce9")
	return label


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Control) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 42
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 23)
	parent.add_child(button)
	return button


func _icon(parent: Control, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size = icon.custom_minimum_size
	parent.add_child(icon)
	return icon
