class_name PlayerSkillButton
extends Control

signal skill_pressed

@onready var grayscale_icon: TextureRect = $GrayscaleIcon
@onready var color_fill: TextureProgressBar = $ColorFill
@onready var hit_button: Button = $HitButton

var gauge_current := 0
var gauge_max := 1
var skill_ready := false
var _pulse_time := 0.0
var _shake_tween: Tween


func _ready() -> void:
	hit_button.pressed.connect(_on_hit_button_pressed)
	_update_visuals()


func configure(icon: Texture2D, maximum: int, display_name: String) -> void:
	grayscale_icon.texture = icon
	color_fill.texture_progress = icon
	gauge_max = maxi(1, maximum)
	hit_button.tooltip_text = "%s · 합성으로 충전" % display_name
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
	hit_button.disabled = false
	hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if skill_ready else Control.CURSOR_ARROW
	set_process(skill_ready)
	if not skill_ready:
		_pulse_time = 0.0
	hit_button.tooltip_text = "%s\n게이지 %d / %d" % [
		hit_button.tooltip_text.get_slice("\n", 0),
		gauge_current,
		gauge_max,
	]
	queue_redraw()


func _on_hit_button_pressed() -> void:
	skill_pressed.emit()
