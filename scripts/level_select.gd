class_name LevelSelect
extends Control

@export_file("*.tscn") var battle_scene_path := "res://scenes/main.tscn"

const SWIPE_THRESHOLD := 65.0

@onready var content: Control = $Content
@onready var level_name_label: Label = $Content/LevelName
@onready var placeholder_label: Label = $Content/LevelImage/PlaceholderText
@onready var boss_silhouette: TextureRect = $Content/LevelImage/BossSilhouette
@onready var lock_overlay: ColorRect = $Content/LevelImage/LockOverlay
@onready var lock_label: Label = $Content/LevelImage/LockOverlay/LockLabel
@onready var start_button: Button = $Content/StartButton
@onready var autoplay_button: Button = $Content/AutoplayButton
@onready var combo_test_button: Button = $Content/ComboTestButton
@onready var previous_button: Button = $PreviousButton
@onready var next_button: Button = $NextButton
@onready var page_label: Label = $PageLabel
@onready var swipe_hint: Label = $SwipeHint

var viewed_level_index := 0
var pointer_start := Vector2.ZERO
var pointer_tracking := false
var page_tween: Tween


func _ready() -> void:
	viewed_level_index = GameSession.selected_level_index
	start_button.pressed.connect(_on_start_button_pressed)
	previous_button.pressed.connect(_show_previous_level)
	next_button.pressed.connect(_show_next_level)
	autoplay_button.visible = OS.is_debug_build()
	autoplay_button.text = "개발 자동 플레이 ON" if GameSession.developer_autoplay_enabled else "개발 자동 플레이 OFF"
	autoplay_button.pressed.connect(_on_autoplay_button_pressed)
	combo_test_button.visible = OS.is_debug_build()
	combo_test_button.pressed.connect(_on_combo_test_button_pressed)
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
	boss_silhouette.texture = _get_level_boss_sprite(level)
	boss_silhouette.visible = boss_silhouette.texture != null
	placeholder_label.text = level.image_placeholder if unlocked else "LOCKED LEVEL\n미리보기"
	lock_overlay.visible = not unlocked
	lock_label.text = "🔒\n이전 스테이지를 클리어하세요"
	start_button.disabled = not unlocked
	start_button.text = "게임 시작" if unlocked else "잠긴 스테이지"
	previous_button.disabled = index <= 0
	next_button.disabled = index >= GameSession.get_level_count() - 1
	page_label.text = "%d / %d" % [index + 1, GameSession.get_level_count()]
	combo_test_button.disabled = not unlocked
	if direction != 0:
		_play_page_transition(direction)


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
