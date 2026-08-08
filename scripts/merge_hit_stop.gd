class_name MergeHitStop
extends Node

var slow_time_scale := 0.25
var duration_seconds := 0.12
var _restore_time_scale := 1.0
var _request_id := 0
var _active := false


func configure(time_scale: float, duration: float) -> void:
	slow_time_scale = clampf(time_scale, 0.05, 1.0)
	duration_seconds = maxf(0.0, duration)


func play() -> void:
	if duration_seconds <= 0.0 or slow_time_scale >= 1.0:
		return
	_request_id += 1
	var current_request := _request_id
	if not _active:
		_restore_time_scale = Engine.time_scale
		_active = true
	Engine.time_scale = slow_time_scale
	# 실제 시간 기준 타이머라 슬로모션 배율의 영향을 받지 않는다.
	await get_tree().create_timer(duration_seconds, true, false, true).timeout
	if current_request == _request_id:
		_restore()


func _exit_tree() -> void:
	_restore()


func _restore() -> void:
	if not _active:
		return
	Engine.time_scale = _restore_time_scale
	_active = false
