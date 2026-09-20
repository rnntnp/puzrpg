extends Control

signal closed
signal play_requested
signal top_down_play_requested
signal flat_throw_play_requested

const Store = preload("res://scripts/gimmicks/merge_loadout_store.gd")
const Tuning = preload("res://scripts/gimmicks/configs/merge_loadout_config.gd")
const Catalog = preload("res://scripts/ball_catalog.gd")
var slots: Array[int] = []
var choices: Array[OptionButton] = []
var descriptions: Array[Label] = []
var move_buttons: Array[Button] = []
var move_source := -1
var status: Label
var tuning: Resource

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(Store.LEVEL_PATH).test_gimmick.tuning
	slots = Store.read_slots()
	var background := ColorRect.new()
	background.color = Color("152a36")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "우파루파 능력 편성 · 발사 물리 비교"
	title.add_theme_font_size_override("font_size", 29)
	column.add_child(title)
	var help := Label.new()
	help.text = "3 + 3 → 4라면 3단계의 능력이 발동합니다.\n기본 공격은 유지됩니다. 같은 능력을 여러 단계에 넣어도 됩니다.\n이동을 누른 뒤 도착 단계를 선택하면 서로 교환합니다."
	help.add_theme_font_size_override("font_size", 18)
	column.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	for index in range(10):
		var block := VBoxContainer.new()
		rows.add_child(block)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = Catalog.get_ball(index).sprite
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(52, 52)
		row.add_child(portrait)
		var label := Label.new()
		label.text = "%d + %d → %d" % [index + 1, index + 1, index + 2]
		label.custom_minimum_size.x = 166
		row.add_child(label)
		var choice := OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for ability_name in Store.NAMES:
			choice.add_item(ability_name)
		choice.item_selected.connect(_assign.bind(index))
		row.add_child(choice)
		choices.append(choice)
		var move := Button.new()
		move.text = "이동"
		move.custom_minimum_size.x = 74
		move.pressed.connect(_move.bind(index))
		row.add_child(move)
		move_buttons.append(move)
		var remove := Button.new()
		remove.text = "해제"
		remove.pressed.connect(_assign.bind(0, index))
		row.add_child(remove)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size", 17)
		block.add_child(detail)
		descriptions.append(detail)
	var maximum := Label.new()
	maximum.text = "11단계 · 최종 우파루파 (다음 합성이 없어 장착하지 않음)"
	maximum.add_theme_font_size_override("font_size", 18)
	rows.add_child(maximum)
	status = Label.new()
	status.text = "편성은 자동 저장되며 51·52·53번 비교 레벨에 적용됩니다."
	status.add_theme_font_size_override("font_size", 17)
	column.add_child(status)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	for caption in ["닫기", "기본 편성"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(button)
		match caption:
			"닫기": button.pressed.connect(func(): closed.emit())
			_: button.pressed.connect(_reset)
	var test_footer := HBoxContainer.new()
	column.add_child(test_footer)
	for caption in ["51 아래→위", "52 위→아래", "53 평면 던지기"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		test_footer.add_child(button)
		match caption:
			"51 아래→위": button.pressed.connect(func(): play_requested.emit())
			"52 위→아래": button.pressed.connect(func(): top_down_play_requested.emit())
			_: button.pressed.connect(func(): flat_throw_play_requested.emit())
	_refresh()

func _assign(ability: int, index: int) -> void:
	slots[index] = ability
	move_source = -1
	_save()

func _move(index: int) -> void:
	if move_source < 0:
		move_source = index
		status.text = "%d단계 능력을 옮길 단계를 누르세요. 같은 단계를 누르면 취소." % (index + 1)
		_refresh()
		return
	var old: int = slots[index]
	slots[index] = slots[move_source]
	slots[move_source] = old
	move_source = -1
	_save()

func _reset() -> void:
	slots.assign(Store.DEFAULTS)
	move_source = -1
	_save()

func _save() -> void:
	var error := Store.write_slots(slots)
	status.text = "편성을 저장했습니다." if error == OK else "저장 실패: %s (저장 경로를 확인해 주세요)" % error_string(error)
	_refresh()

func _refresh() -> void:
	for index in range(slots.size()):
		choices[index].select(slots[index])
		descriptions[index].text = Store.description(index + 1, slots[index], tuning)
		move_buttons[index].text = "취소" if move_source == index else ("여기로" if move_source >= 0 else "이동")
