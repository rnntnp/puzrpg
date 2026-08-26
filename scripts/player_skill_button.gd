class_name PlayerSkillButton
extends Control

signal skill_pressed
signal skill_hover_changed(hovered: bool)

@export_range(40.0, 140.0, 1.0) var interaction_radius := 108.0

@onready var icon_outline: TextureRect = $IconOutline
@onready var grayscale_icon: TextureRect = $GrayscaleIcon
@onready var color_fill: TextureProgressBar = $ColorFill
@onready var ready_glow: SkillReadyOutlinePulse = $ReadyGlow
@onready var hit_button: Button = $HitButton
@onready var touch_area: Control = $TouchArea

var gauge_current := 0
var gauge_max := 1
var skill_ready := false
var _shake_tween: Tween
var _last_press_msec := -1000
var _touch_hovered := false
var _icon_hovered := false
var _hover_active := false
var _icon_hover_tween: Tween
var _gauge_fill_tween: Tween


func _ready() -> void:
	grayscale_icon.visible = true
	color_fill.visible = true
	hit_button.pressed.connect(_on_icon_pressed)
	hit_button.mouse_entered.connect(_on_icon_mouse_entered)
	hit_button.mouse_exited.connect(_on_icon_mouse_exited)
	touch_area.gui_input.connect(_on_touch_area_gui_input)
	touch_area.mouse_entered.connect(_on_touch_area_mouse_entered)
	touch_area.mouse_exited.connect(_on_touch_area_mouse_exited)
	icon_outline.material = icon_outline.material.duplicate()
	icon_outline.pivot_offset = icon_outline.size * 0.5
	grayscale_icon.pivot_offset = grayscale_icon.size * 0.5
	color_fill.pivot_offset = color_fill.size * 0.5
	tooltip_text = ""
	touch_area.tooltip_text = ""
	_update_visuals()


func configure(icon: Texture2D, maximum: int, display_name: String) -> void:
	grayscale_icon.texture = icon
	color_fill.texture_progress = icon
	ready_glow.set_skill_texture(icon)
	icon_outline.texture = icon
	gauge_max = maxi(1, maximum)
	color_fill.max_value = gauge_max
	color_fill.value = gauge_current
	tooltip_text = ""
	touch_area.tooltip_text = ""
	_update_visuals()


func set_gauge(current: int, maximum: int) -> void:
	var was_ready := skill_ready
	var previous_current := gauge_current
	gauge_max = maxi(1, maximum)
	gauge_current = clampi(current, 0, gauge_max)
	skill_ready = gauge_current >= gauge_max
	if was_ready != skill_ready:
		_refresh_hover_feedback()
	_update_visuals()
	_update_gauge_fill(previous_current)


func play_blocked_feedback() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var resting_x := position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position:x", resting_x - 4.0, 0.05)
	_shake_tween.tween_property(self, "position:x", resting_x + 4.0, 0.07)
	_shake_tween.tween_property(self, "position:x", resting_x, 0.05)


func _update_visuals() -> void:
	if not is_node_ready():
		return
	color_fill.max_value = gauge_max
	touch_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if skill_ready else Control.CURSOR_ARROW
	ready_glow.set_active(skill_ready)
	_refresh_hover_feedback()
	tooltip_text = ""
	touch_area.tooltip_text = ""


func _update_gauge_fill(previous_current: int) -> void:
	if _gauge_fill_tween != null and _gauge_fill_tween.is_valid():
		_gauge_fill_tween.kill()
	if gauge_current <= previous_current:
		color_fill.value = gauge_current
		return
	var fill_ratio := float(gauge_current - previous_current) / float(gauge_max)
	var duration := lerpf(0.16, 0.32, clampf(fill_ratio, 0.0, 1.0))
	_gauge_fill_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gauge_fill_tween.tween_property(color_fill, "value", float(gauge_current), duration)


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


func _on_touch_area_mouse_entered() -> void:
	_touch_hovered = true
	_refresh_hover_feedback()


func _on_touch_area_mouse_exited() -> void:
	_touch_hovered = false
	_refresh_hover_feedback()


func _on_icon_pressed() -> void:
	skill_pressed.emit()


func _on_icon_mouse_entered() -> void:
	_icon_hovered = true
	_refresh_hover_feedback()


func _on_icon_mouse_exited() -> void:
	_icon_hovered = false
	_refresh_hover_feedback()


func _refresh_hover_feedback() -> void:
	var should_activate := skill_ready and (_touch_hovered or _icon_hovered)
	if _hover_active == should_activate:
		return
	_hover_active = should_activate
	ready_glow.set_hovered(_hover_active)
	skill_hover_changed.emit(_hover_active)
	if _icon_hover_tween != null and _icon_hover_tween.is_valid():
		_icon_hover_tween.kill()
	var target_scale := Vector2.ONE * (1.06 if _hover_active else 1.0)
	_icon_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_icon_hover_tween.tween_property(icon_outline, "scale", target_scale, 0.12)
	_icon_hover_tween.tween_property(grayscale_icon, "scale", target_scale, 0.12)
	_icon_hover_tween.tween_property(color_fill, "scale", target_scale, 0.12)
