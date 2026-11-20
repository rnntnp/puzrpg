extends RefCounted


## Returns actual damage per slot. The remainder after the rear is discarded.
static func allocate(damage: int, front_hp: Array[int], rear_hp: Array[int]) -> Array[PackedInt32Array]:
	var front_damage := PackedInt32Array()
	var rear_damage := PackedInt32Array()
	damage = _allocate_column(damage, front_hp, front_damage)
	_allocate_column(damage, rear_hp, rear_damage)
	return [front_damage, rear_damage]


@warning_ignore("integer_division")
static func _allocate_column(damage: int, hp: Array[int], applied: PackedInt32Array) -> int:
	applied.resize(hp.size())
	var living: Array[int] = []
	for index in range(hp.size()):
		if hp[index] > 0:
			living.append(index)
	while damage > 0 and not living.is_empty():
		var share := damage / living.size()
		var remainder := damage % living.size()
		var spent := 0
		var survivors: Array[int] = []
		for order in range(living.size()):
			var index := living[order]
			var capacity := hp[index] - applied[index]
			var hit := mini(capacity, share + int(order < remainder))
			applied[index] += hit
			spent += hit
			if hit < capacity:
				survivors.append(index)
		damage -= spent
		living = survivors
	return damage
