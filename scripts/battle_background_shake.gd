extends Node

const HitFeedback = preload("res://scripts/hit_feedback.gd")

@export var minimum_amplitude := 2.0
@export var maximum_amplitude := 12.0

var _background: Control
var _base_position := Vector2.ZERO
var _started_msec := 0
var _duration := 0.0
var _amplitude := 0.0
var _shaking := false
var _direction := 1.0


func configure(background: Control) -> void:
	_background = background
	_base_position = background.position
	set_process(false)


func shake_for_damage(damage: int, started_msec: int, direction: float) -> void:
	if not is_instance_valid(_background):
		return
	if damage < HitFeedback.SHAKE_MINIMUM_DAMAGE:
		return
	_amplitude = clampf(float(damage) * 0.06, minimum_amplitude, maximum_amplitude)
	_duration = HitFeedback.duration(damage)
	_started_msec = started_msec
	_direction = direction
	_shaking = true
	set_process(true)


func _process(_delta: float) -> void:
	if not is_instance_valid(_background):
		set_process(false)
		return
	# Real time keeps the chosen duration independent of merge hit-stop.
	var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var progress := clampf(elapsed / maxf(0.001, _duration), 0.0, 1.0)
	if progress >= 1.0:
		_restore_background()
		set_process(false)
		return
	var displacement: float = HitFeedback.displacement(progress)
	var offset := Vector2(displacement * _amplitude * _direction, 0.0)
	_background.position = _base_position + offset


func _restore_background() -> void:
	if _shaking and is_instance_valid(_background):
		_background.position = _base_position
	_shaking = false
	_amplitude = 0.0


func _exit_tree() -> void:
	_restore_background()
