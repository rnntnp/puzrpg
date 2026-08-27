class_name SuikaBoardSolver
extends Node

const BallStateClass = preload("res://scripts/custom_physics/suika_ball_state.gd")
const ContactStateClass = preload("res://scripts/custom_physics/suika_contact_state.gd")
const CustomPhysicsDataClass = preload("res://scripts/custom_physics/custom_board_physics_data.gd")

var tuning: CustomPhysicsDataClass
var board_bounds := Rect2()
var physics_speed := 1.0
var accumulator := 0.0
var states: Dictionary = {}
var contact_states: Dictionary = {}
var contact_loads: Dictionary = {}
var jam_release_cooldown_remaining := 0.0
var jam_release_count := 0
var last_jam_release_key := ""


func _ready() -> void:
	set_physics_process(false)


func configure(data: CustomPhysicsDataClass, bounds: Rect2, speed_multiplier: float) -> void:
	clear()
	tuning = data
	board_bounds = bounds
	physics_speed = maxf(0.01, speed_multiplier)
	accumulator = 0.0
	set_physics_process(tuning != null)


func is_active() -> bool:
	return tuning != null and is_physics_processing()


func clear() -> void:
	for state: BallStateClass in states.values():
		if state.is_valid():
			state.ball.set_custom_physics_enabled(false)
	states.clear()
	contact_states.clear()
	contact_loads.clear()
	accumulator = 0.0
	jam_release_cooldown_remaining = 0.0
	jam_release_count = 0
	last_jam_release_key = ""


func register_ball(ball: MergeBall) -> void:
	if not is_active() or not is_instance_valid(ball):
		return
	var state := BallStateClass.new() as BallStateClass
	state.configure(ball, tuning.shared_rotational_inertia)
	states[ball.get_instance_id()] = state
	ball.set_custom_physics_enabled(true)
	_sync_ball(state)


func set_ball_velocity(ball: MergeBall, velocity: Vector2, angular_velocity := 0.0) -> void:
	var state := _get_state(ball)
	if state == null:
		ball.linear_velocity = velocity
		ball.angular_velocity = angular_velocity
		return
	state.velocity = velocity
	state.angular_velocity = angular_velocity
	state.wake()
	_sync_ball(state)


func apply_impulse(ball: MergeBall, impulse: Vector2) -> void:
	var state := _get_state(ball)
	if state == null:
		ball.apply_central_impulse(impulse)
		return
	if state.is_static():
		return
	# 테스트 솔버의 모든 기본 공은 질량 1로 계산한다.
	state.velocity += impulse
	state.wake()


func update_bounds(bounds: Rect2) -> void:
	board_bounds = bounds


func _physics_process(delta: float) -> void:
	if tuning == null:
		return
	_prune_invalid_states()
	var fixed_delta := 1.0 / float(maxi(1, tuning.simulation_hz))
	var maximum_accumulator := fixed_delta * float(maxi(1, tuning.maximum_substeps))
	accumulator = minf(accumulator + delta, maximum_accumulator)
	var completed_steps := 0
	while accumulator + 0.000001 >= fixed_delta and completed_steps < tuning.maximum_substeps:
		_step(fixed_delta)
		accumulator -= fixed_delta
		completed_steps += 1
	_sync_all_balls()


func _step(delta: float) -> void:
	var active_states := _get_simulated_states()
	var gravity_acceleration := tuning.gravity * physics_speed * physics_speed
	var linear_retention := exp(-tuning.linear_damping_per_second * delta)
	var angular_retention := exp(-tuning.angular_damping_per_second * delta)
	_begin_contact_step()
	jam_release_cooldown_remaining = maxf(0.0, jam_release_cooldown_remaining - delta)
	for state: BallStateClass in active_states:
		state.radius = maxf(1.0, state.ball.get_radius())
		state.touched_this_step = false
		state.grounded_this_step = false
		if state.is_static() or state.sleeping:
			continue
		state.velocity.y += gravity_acceleration * delta
		state.velocity *= linear_retention
		state.angular_velocity *= angular_retention
		state.position += state.velocity * delta
		state.rotation += state.angular_velocity * delta

	for _iteration in tuning.solver_iterations:
		for state: BallStateClass in active_states:
			_resolve_board_contact(state, delta, gravity_acceleration)
		for first_index in active_states.size():
			for second_index in range(first_index + 1, active_states.size()):
				_resolve_ball_contact(active_states[first_index], active_states[second_index], delta, gravity_acceleration)

	_finalize_contact_step(delta)
	_try_release_jammed_contact(active_states)
	for state: BallStateClass in active_states:
		_update_sleep(state, delta)


func _resolve_ball_contact(
	first: BallStateClass,
	second: BallStateClass,
	delta: float,
	gravity_acceleration: float
) -> void:
	if not first.is_simulated() or not second.is_simulated():
		return
	var offset := second.position - first.position
	var minimum_distance := first.radius + second.radius
	var distance_squared := offset.length_squared()
	if distance_squared > minimum_distance * minimum_distance:
		return
	var distance := sqrt(maxf(distance_squared, 0.000001))
	var normal := offset / distance if distance > 0.001 else Vector2.RIGHT
	var penetration := minimum_distance - distance
	var iteration_count := float(maxi(1, tuning.solver_iterations))
	var support_impulse := (
		gravity_acceleration * delta * 0.5 * absf(normal.y) / iteration_count
		+ maxf(0.0, penetration - tuning.penetration_slop)
			* tuning.position_correction / maxf(delta, 0.0001) / iteration_count
	)
	first.touched_this_step = true
	second.touched_this_step = true
	first.ball.notify_custom_contact()
	second.ball.notify_custom_contact()

	# MergeGame이 기존 합성 위치와 계승 속도를 그대로 읽을 수 있게 현재 고정 스텝을 먼저 반영한다.
	_sync_ball(first)
	_sync_ball(second)
	if first.ball.request_merge_with(second.ball):
		if first.ball.merge_locked or second.ball.merge_locked:
			return
	var contact_memory := _observe_ball_contact(first, second, normal, support_impulse)

	var relative_velocity := second.velocity - first.velocity
	var relative_speed := relative_velocity.length()
	if relative_speed >= tuning.wake_relative_speed or penetration >= tuning.wake_penetration:
		first.wake()
		second.wake()
	elif first.sleeping and second.sleeping:
		return

	var first_inverse_mass := 0.0 if first.is_static() else 1.0
	var second_inverse_mass := 0.0 if second.is_static() else 1.0
	var inverse_mass_sum := first_inverse_mass + second_inverse_mass
	if inverse_mass_sum <= 0.0:
		return

	var corrected_penetration := maxf(0.0, penetration - tuning.penetration_slop)
	if corrected_penetration > 0.0:
		var correction := normal * corrected_penetration * tuning.position_correction / inverse_mass_sum
		first.position -= correction * first_inverse_mass
		second.position += correction * second_inverse_mass

	var normal_speed := relative_velocity.dot(normal)
	var normal_impulse := 0.0
	if normal_speed < 0.0:
		normal_impulse = -(1.0 + tuning.ball_restitution) * normal_speed / inverse_mass_sum
		var impulse := normal * normal_impulse
		first.velocity -= impulse * first_inverse_mass
		second.velocity += impulse * second_inverse_mass
		_observe_ball_contact(first, second, normal, normal_impulse)

	var tangent := Vector2(-normal.y, normal.x)
	var tangent_speed := (
		(second.velocity - first.velocity).dot(tangent)
		- second.angular_velocity * second.radius
		- first.angular_velocity * first.radius
	)
	var tangent_denominator := (
		inverse_mass_sum
		+ first.radius * first.radius * first.inverse_inertia
		+ second.radius * second.radius * second.inverse_inertia
	)
	if tangent_denominator <= 0.0:
		return
	var tangent_impulse := -tangent_speed / tangent_denominator
	var resting_support := gravity_acceleration * delta * 0.5 / float(maxi(1, tuning.solver_iterations))
	var friction_limit := (
		maxf(absf(normal_impulse), resting_support)
		* tuning.ball_friction
		* _get_contact_friction_multiplier(contact_memory)
	)
	tangent_impulse = clampf(tangent_impulse, -friction_limit, friction_limit)
	var friction_impulse := tangent * tangent_impulse
	first.velocity -= friction_impulse * first_inverse_mass
	second.velocity += friction_impulse * second_inverse_mass
	first.angular_velocity -= first.radius * tangent_impulse * first.inverse_inertia
	second.angular_velocity -= second.radius * tangent_impulse * second.inverse_inertia


func _resolve_board_contact(state: BallStateClass, delta: float, gravity_acceleration: float) -> void:
	if not state.is_simulated():
		return
	var minimum_x := board_bounds.position.x + state.radius
	var maximum_x := board_bounds.end.x - state.radius
	var maximum_y := board_bounds.end.y - state.radius
	if state.position.x < minimum_x:
		state.position.x = minimum_x
		_resolve_wall_velocity(state, Vector2.RIGHT, tuning.wall_restitution, tuning.wall_friction, delta, gravity_acceleration)
	elif state.position.x > maximum_x:
		state.position.x = maximum_x
		_resolve_wall_velocity(state, Vector2.LEFT, tuning.wall_restitution, tuning.wall_friction, delta, gravity_acceleration)
	# 아주 약한 바닥 반동으로 한 스텝씩 뜨는 상태를 접촉으로 스냅해 수면 타이머가 끊기지 않게 한다.
	if state.position.y < maximum_y - tuning.penetration_slop:
		return
	state.position.y = maximum_y
	state.touched_this_step = true
	state.grounded_this_step = true
	state.ball.notify_custom_contact()
	var incoming_speed := maxf(0.0, state.velocity.y)
	var normal_support := (
		incoming_speed * (1.0 + tuning.floor_restitution)
		+ gravity_acceleration * delta / float(maxi(1, tuning.solver_iterations))
	)
	var contact_memory := _observe_floor_contact(state, normal_support)
	if state.sleeping:
		return
	if incoming_speed <= tuning.sleep_linear_speed * 2.0:
		state.velocity.y = 0.0
	elif state.velocity.y > 0.0:
		state.velocity.y = -state.velocity.y * tuning.floor_restitution
	var contact_speed := state.velocity.x - state.angular_velocity * state.radius
	var tangent_denominator := 1.0 + state.radius * state.radius * state.inverse_inertia
	var tangent_impulse := -contact_speed / maxf(tangent_denominator, 0.001)
	var friction_limit := (
		normal_support
		* tuning.floor_friction
		* _get_contact_friction_multiplier(contact_memory)
	)
	tangent_impulse = clampf(tangent_impulse, -friction_limit, friction_limit)
	state.velocity.x += tangent_impulse
	state.angular_velocity -= state.radius * tangent_impulse * state.inverse_inertia


func _resolve_wall_velocity(
	state: BallStateClass,
	normal: Vector2,
	restitution: float,
	friction: float,
	delta: float,
	gravity_acceleration: float
) -> void:
	state.touched_this_step = true
	state.ball.notify_custom_contact()
	if state.sleeping:
		return
	var normal_speed := state.velocity.dot(normal)
	var normal_impulse := 0.0
	if normal_speed < 0.0:
		normal_impulse = -(1.0 + restitution) * normal_speed
		state.velocity += normal * normal_impulse
	var tangent := Vector2(-normal.y, normal.x)
	var tangent_speed := state.velocity.dot(tangent) - state.angular_velocity * state.radius
	var tangent_denominator := 1.0 + state.radius * state.radius * state.inverse_inertia
	var tangent_impulse := -tangent_speed / maxf(tangent_denominator, 0.001)
	var friction_limit := maxf(normal_impulse, gravity_acceleration * delta * 0.1) * friction
	tangent_impulse = clampf(tangent_impulse, -friction_limit, friction_limit)
	state.velocity += tangent * tangent_impulse
	state.angular_velocity -= state.radius * tangent_impulse * state.inverse_inertia


func _begin_contact_step() -> void:
	contact_loads.clear()
	for contact: ContactStateClass in contact_states.values():
		contact.begin_step()


func _observe_ball_contact(
	first: BallStateClass,
	second: BallStateClass,
	normal_from_first: Vector2,
	pressure_impulse: float
) -> ContactStateClass:
	var first_id := first.ball.get_instance_id()
	var second_id := second.ball.get_instance_id()
	var lower_id := mini(first_id, second_id)
	var upper_id := maxi(first_id, second_id)
	var key := "b:%d:%d" % [lower_id, upper_id]
	var contact := contact_states.get(key) as ContactStateClass
	if contact == null:
		contact = ContactStateClass.new() as ContactStateClass
		contact.configure(key, lower_id, upper_id)
		contact_states[key] = contact
	var stored_normal := normal_from_first if first_id == lower_id else -normal_from_first
	contact.observe(stored_normal, pressure_impulse)
	return contact


func _observe_floor_contact(state: BallStateClass, pressure_impulse: float) -> ContactStateClass:
	var ball_id := state.ball.get_instance_id()
	var key := "f:%d" % ball_id
	var contact := contact_states.get(key) as ContactStateClass
	if contact == null:
		contact = ContactStateClass.new() as ContactStateClass
		contact.configure(key, ball_id, 0)
		contact_states[key] = contact
	contact.observe(Vector2.UP, pressure_impulse)
	return contact


func _get_contact_friction_multiplier(contact: ContactStateClass) -> float:
	if not tuning.jam_slip_enabled or contact == null:
		return 1.0
	if contact.slip_remaining > 0.0:
		return tuning.jam_slip_friction_multiplier
	var weakening_time := maxf(0.0, contact.age - tuning.jam_friction_weakening_delay)
	return maxf(
		tuning.jam_minimum_friction_multiplier,
		1.0 - weakening_time * tuning.jam_friction_weakening_per_second
	)


func _finalize_contact_step(delta: float) -> void:
	var ended_keys: Array[String] = []
	for key: String in contact_states:
		var contact := contact_states[key] as ContactStateClass
		if contact == null or not contact.seen_this_step:
			ended_keys.append(key)
			continue
		contact.advance(
			delta,
			tuning.jam_pressure_storage_ratio,
			tuning.jam_maximum_stored_energy
		)
		if contact.second_id == 0:
			_add_contact_load(contact.first_id, contact.normal * contact.pressure_impulse)
		else:
			_add_contact_load(contact.first_id, -contact.normal * contact.pressure_impulse)
			_add_contact_load(contact.second_id, contact.normal * contact.pressure_impulse)
	for key in ended_keys:
		contact_states.erase(key)


func _add_contact_load(instance_id: int, load: Vector2) -> void:
	var accumulated: Vector2 = contact_loads.get(instance_id, Vector2.ZERO)
	contact_loads[instance_id] = accumulated + load


func _try_release_jammed_contact(active_states: Array[BallStateClass]) -> void:
	if not tuning.jam_slip_enabled or jam_release_cooldown_remaining > 0.0:
		return
	if _calculate_kinetic_energy(active_states) >= tuning.jam_kinetic_energy_threshold:
		return
	var selected: ContactStateClass
	var selected_bias := 0.0
	var selected_score := -1.0
	for contact: ContactStateClass in contact_states.values():
		if (
			not contact.seen_this_step
			or contact.age < tuning.jam_minimum_contact_age
			or contact.stored_pressure_energy < tuning.jam_minimum_release_energy
		):
			continue
		# 바닥에 혼자 놓인 공은 압력이 커도 방출 명분이 없다.
		# 다른 공과 동시에 맞물린 바닥 접촉만 pile의 국소 slip 후보가 된다.
		if contact.second_id == 0 and not _has_active_ball_contact(contact.first_id):
			continue
		var direction_bias := _get_contact_direction_bias(contact)
		if absf(direction_bias) < tuning.jam_direction_epsilon:
			continue
		var score := (
			contact.stored_pressure_energy
			* maxf(contact.pressure_impulse, 0.01)
			* (1.0 + contact.age)
		)
		if score > selected_score:
			selected = contact
			selected_bias = direction_bias
			selected_score = score
	if selected == null:
		return
	_release_contact_energy(selected, selected_bias)


func _has_active_ball_contact(instance_id: int) -> bool:
	for contact: ContactStateClass in contact_states.values():
		if not contact.seen_this_step or contact.second_id == 0:
			continue
		if contact.first_id == instance_id or contact.second_id == instance_id:
			return true
	return false


func _get_contact_direction_bias(contact: ContactStateClass) -> float:
	var first := _get_state_by_id(contact.first_id)
	if first == null or first.is_static():
		return 0.0
	var tangent := Vector2(-contact.normal.y, contact.normal.x)
	var first_load: Vector2 = contact_loads.get(contact.first_id, Vector2.ZERO)
	if contact.second_id == 0:
		var floor_surface_speed := first.velocity.dot(tangent) - first.angular_velocity * first.radius
		return floor_surface_speed + first_load.dot(tangent) * tuning.jam_contact_load_bias_scale
	var second := _get_state_by_id(contact.second_id)
	if second == null or second.is_static():
		return 0.0
	var second_load: Vector2 = contact_loads.get(contact.second_id, Vector2.ZERO)
	var relative_surface_speed := (
		(second.velocity - first.velocity).dot(tangent)
		- second.angular_velocity * second.radius
		- first.angular_velocity * first.radius
	)
	var load_asymmetry := (second_load - first_load).dot(tangent)
	return relative_surface_speed + load_asymmetry * tuning.jam_contact_load_bias_scale


func _release_contact_energy(contact: ContactStateClass, direction_bias: float) -> void:
	var first := _get_state_by_id(contact.first_id)
	if first == null or first.is_static():
		return
	var tangent := Vector2(-contact.normal.y, contact.normal.x)
	var direction := 1.0 if direction_bias > 0.0 else -1.0
	var magnitude := minf(
		tuning.jam_maximum_release_impulse,
		contact.stored_pressure_energy * tuning.jam_energy_to_impulse
	)
	if magnitude <= 0.0:
		return
	var impulse := tangent * direction * magnitude
	if contact.second_id == 0:
		first.velocity += impulse
		first.angular_velocity -= first.radius * direction * magnitude * first.inverse_inertia
		first.wake()
	else:
		var second := _get_state_by_id(contact.second_id)
		if second == null or second.is_static():
			return
		first.velocity -= impulse
		second.velocity += impulse
		first.angular_velocity -= first.radius * direction * magnitude * first.inverse_inertia
		second.angular_velocity -= second.radius * direction * magnitude * second.inverse_inertia
		first.wake()
		second.wake()
	contact.consume_energy(tuning.jam_release_energy_fraction, tuning.jam_slip_duration)
	jam_release_cooldown_remaining = tuning.jam_release_cooldown
	jam_release_count += 1
	last_jam_release_key = contact.key


func _calculate_kinetic_energy(active_states: Array[BallStateClass]) -> float:
	var total := 0.0
	for state: BallStateClass in active_states:
		if state.is_static():
			continue
		var inertia := 1.0 / maxf(state.inverse_inertia, 0.000001)
		total += 0.5 * state.velocity.length_squared()
		total += 0.5 * inertia * state.angular_velocity * state.angular_velocity
	return total


func _get_state_by_id(instance_id: int) -> BallStateClass:
	return states.get(instance_id) as BallStateClass


func get_jam_debug_snapshot() -> Dictionary:
	var stored_energy := 0.0
	var aged_contacts := 0
	for contact: ContactStateClass in contact_states.values():
		stored_energy += contact.stored_pressure_energy
		if contact.age >= tuning.jam_minimum_contact_age:
			aged_contacts += 1
	return {
		"active_contacts": contact_states.size(),
		"aged_contacts": aged_contacts,
		"stored_pressure_energy": stored_energy,
		"release_count": jam_release_count,
		"last_release_key": last_jam_release_key,
		"cooldown_remaining": jam_release_cooldown_remaining,
	}


func _update_sleep(state: BallStateClass, delta: float) -> void:
	if state.is_static():
		return
	if (
		state.touched_this_step
		and state.velocity.length() <= tuning.sleep_linear_speed
		and absf(state.angular_velocity) <= tuning.sleep_angular_speed
	):
		state.sleep_elapsed += delta
		if state.sleep_elapsed >= tuning.sleep_delay:
			state.sleeping = true
			state.velocity = Vector2.ZERO
			state.angular_velocity = 0.0
	else:
		state.sleep_elapsed = 0.0
		state.sleeping = false


func _get_simulated_states() -> Array[BallStateClass]:
	var result: Array[BallStateClass] = []
	for state: BallStateClass in states.values():
		if state.is_simulated():
			result.append(state)
	return result


func _get_state(ball: MergeBall) -> BallStateClass:
	if not is_instance_valid(ball):
		return null
	return states.get(ball.get_instance_id()) as BallStateClass


func _prune_invalid_states() -> void:
	var invalid_ids: Array[int] = []
	for instance_id: int in states:
		var state := states[instance_id] as BallStateClass
		if state == null or not state.is_valid():
			invalid_ids.append(instance_id)
	for instance_id in invalid_ids:
		states.erase(instance_id)


func _sync_all_balls() -> void:
	for state: BallStateClass in states.values():
		if state.is_valid():
			_sync_ball(state)


func _sync_ball(state: BallStateClass) -> void:
	state.ball.position = state.position
	state.ball.rotation = state.rotation
	state.ball.linear_velocity = state.velocity
	state.ball.angular_velocity = state.angular_velocity
	state.ball.sleeping = state.sleeping
