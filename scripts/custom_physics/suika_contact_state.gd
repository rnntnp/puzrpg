class_name SuikaContactState
extends RefCounted

var key := ""
var first_id := 0
var second_id := 0
var normal := Vector2.UP
var age := 0.0
var stored_pressure_energy := 0.0
var pressure_impulse := 0.0
var seen_this_step := false
var slip_remaining := 0.0


func configure(contact_key: String, first_body_id: int, second_body_id: int) -> void:
	key = contact_key
	first_id = first_body_id
	second_id = second_body_id


func begin_step() -> void:
	seen_this_step = false
	pressure_impulse = 0.0


func observe(contact_normal: Vector2, impulse: float) -> void:
	seen_this_step = true
	normal = contact_normal.normalized() if not contact_normal.is_zero_approx() else Vector2.UP
	pressure_impulse = maxf(pressure_impulse, maxf(0.0, impulse))


func advance(delta: float, storage_ratio: float, maximum_energy: float) -> void:
	age += delta
	slip_remaining = maxf(0.0, slip_remaining - delta)
	# pressure_impulse는 이미 고정 스텝 동안 적분된 접촉 충격량이므로 dt를 다시 곱하지 않는다.
	stored_pressure_energy = minf(
		maximum_energy,
		stored_pressure_energy + pressure_impulse * maxf(0.0, storage_ratio)
	)


func consume_energy(fraction: float, slip_duration: float) -> void:
	stored_pressure_energy *= 1.0 - clampf(fraction, 0.0, 1.0)
	age = 0.0
	slip_remaining = maxf(slip_remaining, slip_duration)
