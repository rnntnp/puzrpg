class_name PlayerSkillButton
extends Control

signal skill_pressed

@export_range(40.0, 140.0, 1.0) var interaction_radius := 108.0

@onready var grayscale_icon: TextureRect = $GrayscaleIcon
@onready var color_fill: TextureProgressBar = $ColorFill
@onready var hit_button: Button = $HitButton
@onready var touch_area: Control = $TouchArea

var gauge_current := 0
var gauge_max := 1
var skill_ready := false
var _pulse_time := 0.0
var _shake_tween: Tween
var _last_press_msec := -1000


func _ready() -> void:
	grayscale_icon.visible = true
	color_fill.visible = true
	hit_button.visible = false
	touch_area.gui_input.connect(_on_touch_area_gui_input)
	_update_visuals()


func configure(icon: Texture2D, maximum: int, display_name: String) -> void:
	grayscale_icon.texture = icon
	color_fill.texture_progress = icon
	gauge_max = maxi(1, maximum)
	touch_area.tooltip_text = "%s · 주인공을 눌러 사용" % display_name
	_update_visuals()


func set_gauge(current: int, maximum: int) -> void:
	gauge_max = maxi(1, maximum)
	gauge_current = clampi(current, 0, gauge_max)
	skill_ready = gauge_current >= gauge_max
	_update_visuals()


func play_blocked_feedback() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var resting_x := position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position:x", resting_x - 4.0, 0.05)
	_shake_tween.tween_property(self, "position:x", resting_x + 4.0, 0.07)
	_shake_tween.tween_property(self, "position:x", resting_x, 0.05)


func _process(delta: float) -> void:
	if not skill_ready:
		return
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center + Vector2(0.0, 3.0), 35.0, Color(0.02, 0.04, 0.09, 0.65))
	if skill_ready:
		var pulse := (sin(_pulse_time * 4.2) + 1.0) * 0.5
		draw_circle(center, lerpf(37.0, 43.0, pulse), Color(1.0, 0.77, 0.18, lerpf(0.18, 0.34, pulse)))
		draw_arc(center, lerpf(34.0, 38.0, pulse), 0.0, TAU, 48, Color(1.0, 0.9, 0.42, 0.95), 3.0)
	else:
		draw_circle(center, 35.0, Color(0.12, 0.17, 0.25, 0.9))
		draw_arc(center, 34.0, 0.0, TAU, 48, Color(0.48, 0.58, 0.72, 0.72), 2.0)


func _update_visuals() -> void:
	if not is_node_ready():
		return
	color_fill.max_value = gauge_max
	color_fill.value = gauge_current
	touch_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if skill_ready else Control.CURSOR_ARROW
	set_process(skill_ready)
	if not skill_ready:
		_pulse_time = 0.0
	touch_area.tooltip_text = "%s\n게이지 %d / %d" % [
		touch_area.tooltip_text.get_slice("\n", 0),
		gauge_current,
		gauge_max,
	]
	queue_redraw()


func _on_touch_area_gui_input(event: InputEvent) -> void:
	var pressed := false
	var local_press_position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		local_press_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		local_press_position = event.position
	if not pressed or local_press_position.distance_to(touch_area.size * 0.5) > interaction_radius:
		return
	var now := Time.get_ticks_msec()
	if now - _last_press_msec < 120:
		return
	_last_press_msec = now
	accept_event()
	skill_pressed.emit()
