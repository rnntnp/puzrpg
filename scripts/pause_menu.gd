class_name PauseMenu
extends CanvasLayer

const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

@onready var pause_button: Button = $PauseButton
@onready var menu_overlay: Control = $MenuOverlay
@onready var close_button: Button = $MenuOverlay/CloseButton
@onready var resume_button: Button = $MenuOverlay/MenuPanel/Margin/Content/ResumeButton
@onready var exit_button: Button = $MenuOverlay/MenuPanel/Margin/Content/ExitButton
@onready var bgm_slider: HSlider = $MenuOverlay/MenuPanel/Margin/Content/BgmRow/BgmSlider
@onready var bgm_value: Label = $MenuOverlay/MenuPanel/Margin/Content/BgmRow/BgmValue
@onready var sfx_slider: HSlider = $MenuOverlay/MenuPanel/Margin/Content/SfxRow/SfxSlider
@onready var sfx_value: Label = $MenuOverlay/MenuPanel/Margin/Content/SfxRow/SfxValue
@onready var confirmation_overlay: Control = $MenuOverlay/ConfirmationOverlay
@onready var exit_cancel_button: Button = $MenuOverlay/ConfirmationOverlay/ConfirmPanel/Margin/Content/Buttons/CancelButton
@onready var exit_confirm_button: Button = $MenuOverlay/ConfirmationOverlay/ConfirmPanel/Margin/Content/Buttons/ConfirmButton

var exit_button_tween: Tween
var exit_button_is_pressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_open_menu)
	close_button.pressed.connect(_close_menu)
	resume_button.pressed.connect(_close_menu)
	exit_button.pressed.connect(_show_exit_confirmation)
	exit_button.mouse_entered.connect(_on_exit_button_mouse_entered)
	exit_button.mouse_exited.connect(_on_exit_button_mouse_exited)
	exit_button.button_down.connect(_on_exit_button_down)
	exit_button.button_up.connect(_on_exit_button_up)
	exit_button.resized.connect(_setup_exit_button_pivot)
	_setup_exit_button_pivot.call_deferred()
	exit_cancel_button.pressed.connect(_hide_exit_confirmation)
	exit_confirm_button.pressed.connect(_exit_to_level_select)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	bgm_slider.value = AudioSettings.bgm_volume * 100.0
	sfx_slider.value = AudioSettings.sfx_volume * 100.0
	_update_volume_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if confirmation_overlay.visible:
		_hide_exit_confirmation()
	elif menu_overlay.visible:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	menu_overlay.visible = true
	confirmation_overlay.visible = false
	get_tree().paused = true
	exit_button.grab_focus()


func _close_menu() -> void:
	confirmation_overlay.visible = false
	menu_overlay.visible = false
	get_tree().paused = false
	pause_button.grab_focus()


func _show_exit_confirmation() -> void:
	confirmation_overlay.visible = true
	exit_cancel_button.grab_focus()


func _hide_exit_confirmation() -> void:
	confirmation_overlay.visible = false
	exit_button.grab_focus()


func _exit_to_level_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_bgm_volume_changed(value: float) -> void:
	AudioSettings.set_bgm_volume(value / 100.0)
	_update_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	AudioSettings.set_sfx_volume(value / 100.0)
	_update_volume_labels()


func _update_volume_labels() -> void:
	bgm_value.text = "%d%%" % roundi(bgm_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _setup_exit_button_pivot() -> void:
	exit_button.pivot_offset = exit_button.size * 0.5


func _on_exit_button_mouse_entered() -> void:
	if not exit_button_is_pressed:
		_animate_exit_button(Vector2.ONE * 1.035, Color(1.06, 1.06, 1.06, 1.0))


func _on_exit_button_mouse_exited() -> void:
	if not exit_button_is_pressed:
		_animate_exit_button(Vector2.ONE, Color.WHITE)


func _on_exit_button_down() -> void:
	exit_button_is_pressed = true
	_animate_exit_button(Vector2.ONE * 0.96, Color(0.9, 0.9, 0.9, 1.0), 0.06)


func _on_exit_button_up() -> void:
	exit_button_is_pressed = false
	var hovered_scale := Vector2.ONE * 1.035 if exit_button.is_hovered() else Vector2.ONE
	var hovered_color := Color(1.06, 1.06, 1.06, 1.0) if exit_button.is_hovered() else Color.WHITE
	_animate_exit_button(hovered_scale, hovered_color, 0.08)


func _animate_exit_button(target_scale: Vector2, target_color: Color, duration := 0.1) -> void:
	if exit_button_tween != null and exit_button_tween.is_valid():
		exit_button_tween.kill()
	exit_button_tween = create_tween().set_parallel(true)
	exit_button_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit_button_tween.tween_property(exit_button, "scale", target_scale, duration)
	exit_button_tween.tween_property(exit_button, "self_modulate", target_color, duration)
