extends RefCounted
## Visual cage constraints only. Collision bodies and velocities are untouched.
const COUNT := 6

static func bind(point: Vector2, rest: PackedVector2Array) -> PackedFloat32Array:
	var center := Vector2.ZERO
	for p in rest: center += p / COUNT
	var relative := point - center
	var weights := PackedFloat32Array()
	weights.resize(COUNT)
	weights.fill(1.0 / COUNT)
	for i in COUNT:
		var j := (i + 1) % COUNT
		var a := rest[i] - center
		var b := rest[j] - center
		var determinant := a.cross(b)
		if absf(determinant) < 0.000001: continue
		var x := relative.cross(b) / determinant
		var y := a.cross(relative) / determinant
		if x < -0.00001 or y < -0.00001: continue
		weights.fill((1.0 - x - y) / COUNT)
		weights[i] += x
		weights[j] += y
		break
	return weights

static func offset(state: Dictionary, weights: PackedFloat32Array) -> Vector2:
	var value := Vector2.ZERO
	var offsets: PackedVector2Array = state.offsets
	for i in COUNT: value += offsets[i] * weights[i]
	return value

static func pin(state: Dictionary, anchor: Dictionary) -> void:
	var weights: PackedFloat32Array = anchor.weights
	var error: Vector2 = offset(state, weights) - (anchor.target - anchor.point)
	if error.length_squared() < 0.0025: return
	for i in COUNT:
		state.offsets[i] -= error * (weights[i] / anchor.denominator)

static func clip(state: Dictionary, anchor: Dictionary) -> void:
	var weights: PackedFloat32Array = anchor.weights
	var point: Vector2 = state.to_board * (anchor.point + offset(state, weights))
	var normal: Vector2 = anchor.normal
	var depth: float = point.dot(normal) - anchor.distance
	if depth <= 0.02: return
	var transform: Transform2D = state.to_board
	var gradient := Vector2(transform.x.dot(normal), transform.y.dot(normal))
	var scale: float = depth / (anchor.denominator * gradient.length_squared())
	for i in COUNT:
		state.offsets[i] -= gradient * (weights[i] * scale)
		var speed: float = state.velocities[i].dot(gradient)
		if speed > 0: state.velocities[i] -= gradient * (speed / gradient.length_squared())

## A bounded visual heuristic from normal velocity change, not material stiffness.
## Equal response remains 50:50; tangent motion and common travel do not bias it.
static func impact_share(change_a: Vector2,change_b: Vector2,normal: Vector2) -> float:
	var response_a := maxf(0.0,-change_a.dot(normal))
	var response_b := maxf(0.0,change_b.dot(normal))
	var total := response_a+response_b
	# Ignore integrator noise and resting contact load at low speeds.
	if total<20.0: return 0.5
	return clampf(response_a/total,0.25,0.75)
