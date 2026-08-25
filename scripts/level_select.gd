class_name LevelSelect
extends Control

@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

const SWIPE_THRESHOLD := 65.0
const PREVIEW_VERTICAL_OFFSET_PIXELS := -350.0

@onready var content: Control = $Content
@onready var level_name_label: Label = $Content/LevelName
@onready var placeholder_label: Label = $Content/LevelImage/PlaceholderText
@onready var level_preview: TextureRect = $Content/LevelImage/PreviewBackground
@onready var boss_silhouette: TextureRect = $Content/LevelImage/BossSilhouette
@onready var lock_overlay: ColorRect = $Content/LevelImage/LockOverlay
@onready var lock_label: Label = $Content/LevelImage/LockOverlay/LockLabel
@onready var start_button: Button = $Content/StartButton
@onready var start_button_frame: Panel = $Content/StartButton/CommonFrame
@onready var autoplay_button: Button = $Content/AutoplayButton
@onready var combo_test_button: Button = $Content/ComboTestButton
@onready var previous_button: Button = $PreviousButton
@onready var next_button: Button = $NextButton
@onready var page_label: Label = $PageLabel
@onready var swipe_hint: Label = $SwipeHint
@onready var money_value: Label = $MoneyDisplay/Value
@onready var gimmick_value: Label = $Content/InfoCardLeft/Value
@onready var gimmick_icon: TextureRect = $Content/InfoCardLeft/Icon
@onready var reward_value: Label = $Content/InfoCardLeft3/Value

var viewed_level_index := 0
var pointer_start := Vector2.ZERO
var pointer_tracking := false
var page_tween: Tween
var start_button_tween: Tween
var start_button_is_pressed := false


func _ready() -> void:
	level_preview.material = level_preview.material.duplicate()
	level_preview.resized.connect(_update_preview_mask_mapping)
	viewed_level_index = GameSession.selected_level_index
	start_button.pressed.connect(_on_start_button_pressed)
	start_button.mouse_entered.connect(_on_start_button_mouse_entered)
	start_button.mouse_exited.connect(_on_start_button_mouse_exited)
	start_button.button_down.connect(_on_start_button_down)
	start_button.button_up.connect(_on_start_button_up)
	start_button.focus_entered.connect(_on_start_button_focus_entered)
	start_button.focus_exited.connect(_on_start_button_focus_exited)
	_setup_start_button_pivot.call_deferred()
	previous_button.pressed.connect(_show_previous_level)
	next_button.pressed.connect(_show_next_level)
	autoplay_button.visible = OS.is_debug_build()
	autoplay_button.text = "개발 자동 플레이 ON" if GameSession.developer_autoplay_enabled else "개발 자동 플레이 OFF"
	autoplay_button.pressed.connect(_on_autoplay_button_pressed)
	combo_test_button.visible = OS.is_debug_build()
	combo_test_button.pressed.connect(_on_combo_test_button_pressed)
	GameSession.money_changed.connect(_update_money_display)
	_update_money_display(GameSession.get_money())
	_show_level(viewed_level_index)
	_play_swipe_hint()
	if GameSession.developer_autoplay_enabled:
		_auto_start_level()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_swipe(event.position)
		else:
			_end_swipe(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_swipe(event.position)
		else:
			_end_swipe(event.position)


func _begin_swipe(position: Vector2) -> void:
	pointer_start = position
	pointer_tracking = true


func _end_swipe(position: Vector2) -> void:
	if not pointer_tracking:
		return
	pointer_tracking = false
	var movement := position - pointer_start
	if absf(movement.x) < SWIPE_THRESHOLD or absf(movement.x) < absf(movement.y):
		return
	if movement.x < 0.0:
		_show_next_level()
	else:
		_show_previous_level()
	get_viewport().set_input_as_handled()


func _show_previous_level() -> void:
	if viewed_level_index > 0:
		_show_level(viewed_level_index - 1, -1)


func _show_next_level() -> void:
	if viewed_level_index + 1 < GameSession.get_level_count():
		_show_level(viewed_level_index + 1, 1)


func _show_level(index: int, direction := 0) -> void:
	var level = GameSession.get_level_at(index)
	if level == null:
		return
	viewed_level_index = index
	var unlocked := GameSession.is_level_unlocked(index)
	level_name_label.text = level.level_name
	level_preview.texture = level.battle_background if level.battle_background != null else level.level_select_preview
	level_preview.visible = level_preview.texture != null
	_update_preview_mask_mapping.call_deferred()
	_update_level_info(level)
	boss_silhouette.texture = _get_level_boss_sprite(level)
	boss_silhouette.visible = boss_silhouette.texture != null
	placeholder_label.visible = not level_preview.visible
	placeholder_label.text = level.image_placeholder if unlocked else "LOCKED LEVEL\n미리보기"
	lock_overlay.visible = not unlocked
	lock_label.text = "🔒\n이전 스테이지를 클리어하세요"
	start_button.disabled = not unlocked
	start_button.text = "게임 시작" if unlocked else "잠긴 스테이지"
	if not unlocked:
		_reset_start_button_visual()
	previous_button.visible = index > 0
	next_button.visible = index < GameSession.get_level_count() - 1
	previous_button.disabled = not previous_button.visible
	next_button.disabled = not next_button.visible
	page_label.text = "%d / %d" % [index + 1, GameSession.get_level_count()]
	combo_test_button.disabled = not unlocked
	if direction != 0:
		_play_page_transition(direction)


func _setup_start_button_pivot() -> void:
	start_button.pivot_offset = start_button.size * 0.5


func _on_start_button_mouse_entered() -> void:
	if not start_button.disabled and not start_button_is_pressed:
		_animate_start_button(Vector2.ONE * 1.025, Color(1.06, 1.06, 1.06, 1.0))


func _on_start_button_mouse_exited() -> void:
	if not start_button_is_pressed:
		_animate_start_button(Vector2.ONE, Color.WHITE)


func _on_start_button_down() -> void:
	if start_button.disabled:
		return
	start_button_is_pressed = true
	_animate_start_button(Vector2.ONE * 0.97, Color(0.92, 0.92, 0.92, 1.0), 0.06)


func _on_start_button_up() -> void:
	start_button_is_pressed = false
	if start_button.disabled:
		_reset_start_button_visual()
		return
	var target_scale := Vector2.ONE * 1.025 if start_button.is_hovered() else Vector2.ONE
	var target_color := Color(1.06, 1.06, 1.06, 1.0) if start_button.is_hovered() else Color.WHITE
	_animate_start_button(target_scale, target_color, 0.1)


func _on_start_button_focus_entered() -> void:
	if not start_button.disabled and not start_button_is_pressed:
		_animate_start_button(Vector2.ONE * 1.025, Color(1.06, 1.06, 1.06, 1.0))


func _on_start_button_focus_exited() -> void:
	if not start_button.is_hovered() and not start_button_is_pressed:
		_animate_start_button(Vector2.ONE, Color.WHITE)


func _animate_start_button(target_scale: Vector2, target_color: Color, duration := 0.1) -> void:
	if start_button_tween != null and start_button_tween.is_valid():
		start_button_tween.kill()
	start_button_tween = create_tween().set_parallel(true)
	start_button_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	start_button_tween.tween_property(start_button, "scale", target_scale, duration)
	start_button_tween.tween_property(start_button_frame, "self_modulate", target_color, duration)


func _reset_start_button_visual() -> void:
	start_button_is_pressed = false
	if start_button_tween != null and start_button_tween.is_valid():
		start_button_tween.kill()
	start_button.scale = Vector2.ONE
	start_button_frame.self_modulate = Color.WHITE


func _update_level_info(level: LevelData) -> void:
	gimmick_value.text = level.stage_gimmick_name
	gimmick_icon.texture = level.stage_gimmick_icon
	reward_value.text = level.reward_name


func _update_money_display(amount: int) -> void:
	var digits := str(maxi(0, amount))
	var formatted := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	money_value.text = formatted


func _update_preview_mask_mapping() -> void:
	if level_preview.texture == null or not level_preview.material is ShaderMaterial:
		return
	var texture_size := level_preview.texture.get_size()
	var rect_size := level_preview.size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return
	var texture_aspect := texture_size.x / texture_size.y
	var rect_aspect := rect_size.x / rect_size.y
	var visible_offset := Vector2.ZERO
	var visible_scale := Vector2.ONE
	if texture_aspect > rect_aspect:
		visible_scale.x = rect_aspect / texture_aspect
		visible_offset.x = (1.0 - visible_scale.x) * 0.5
	elif texture_aspect < rect_aspect:
		visible_scale.y = texture_aspect / rect_aspect
		visible_offset.y = (1.0 - visible_scale.y) * 0.5
	level_preview.material.set_shader_parameter("visible_uv_offset", visible_offset)
	level_preview.material.set_shader_parameter("visible_uv_scale", visible_scale)
	level_preview.material.set_shader_parameter(
		"texture_uv_offset",
		Vector2(0.0, PREVIEW_VERTICAL_OFFSET_PIXELS / texture_size.y)
	)


func _get_level_boss_sprite(level: Resource) -> Texture2D:
	if level == null or level.enemies.is_empty():
		return null
	var boss = level.enemies.back()
	return boss.sprite if boss != null else null


func _play_page_transition(direction: int) -> void:
	if page_tween != null and page_tween.is_valid():
		page_tween.kill()
	content.position.x = float(direction) * 55.0
	content.modulate.a = 0.55
	page_tween = create_tween().set_parallel(true)
	page_tween.tween_property(content, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	page_tween.tween_property(content, "modulate:a", 1.0, 0.18)


func _play_swipe_hint() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(swipe_hint, "position:x", swipe_hint.position.x + 12.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.tween_property(swipe_hint, "position:x", swipe_hint.position.x, 0.65).set_trans(Tween.TRANS_SINE)


func _on_start_button_pressed() -> void:
	if not GameSession.select_level(viewed_level_index):
		return
	start_button.disabled = true
	get_tree().change_scene_to_file(battle_scene_path)


func _on_autoplay_button_pressed() -> void:
	GameSession.developer_autoplay_enabled = not GameSession.developer_autoplay_enabled
	autoplay_button.text = "개발 자동 플레이 ON" if GameSession.developer_autoplay_enabled else "개발 자동 플레이 OFF"
	if GameSession.developer_autoplay_enabled and GameSession.is_level_unlocked(viewed_level_index):
		GameSession.select_level(viewed_level_index)
		_auto_start_level()


func _auto_start_level() -> void:
	start_button.disabled = true
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree() and GameSession.developer_autoplay_enabled:
		get_tree().change_scene_to_file(battle_scene_path)


func _on_combo_test_button_pressed() -> void:
	if not GameSession.select_level(viewed_level_index):
		return
	start_button.disabled = true
	autoplay_button.disabled = true
	combo_test_button.disabled = true
	GameSession.developer_autoplay_enabled = false
	GameSession.request_combo_test()
	get_tree().change_scene_to_file(battle_scene_path)


func _show_all_levels() -> void:
	var overlay := ColorRect.new()
	overlay.name = "AllLevelsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.05, 0.1, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 20
	add_child(overlay)

	var title := Label.new()
	title.text = "전체 레벨 선택"
	title.position = Vector2(32, 28)
	title.size = Vector2(500, 60)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#eaf6ff"))
	overlay.add_child(title)

	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.position = Vector2(585, 28)
	close_button.size = Vector2(105, 58)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(overlay.queue_free)
	overlay.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 108)
	scroll.size = Vector2(672, 1100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for index in range(GameSession.get_level_count()):
		var level: LevelData = GameSession.get_level_at(index)
		if level == null:
			continue
		var level_button := Button.new()
		level_button.custom_minimum_size = Vector2(212, 92)
		level_button.add_theme_font_size_override("font_size", 18)
		var unlocked := GameSession.is_level_unlocked(index)
		level_button.text = "%02d\n%s" % [index + 1, _short_level_name(level.level_name)]
		level_button.disabled = not unlocked
		if not unlocked:
			level_button.text += "\n🔒"
		level_button.pressed.connect(_select_from_all_levels.bind(index, overlay))
		grid.add_child(level_button)


func _short_level_name(full_name: String) -> String:
	var separator := full_name.find("·")
	if separator >= 0:
		return full_name.substr(separator + 1).strip_edges().split("/")[0].strip_edges()
	return full_name


func _select_from_all_levels(index: int, overlay: Control) -> void:
	if not GameSession.select_level(index):
		return
	viewed_level_index = index
	overlay.queue_free()
	get_tree().change_scene_to_file(battle_scene_path)
