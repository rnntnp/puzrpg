extends RefCounted


@warning_ignore("integer_division")
static func allocate(damage: int, target: int, hp: Array[int]) -> Array[PackedInt32Array]:
	var phases: Array[PackedInt32Array] = []
	if damage <= 0 or target < 0 or target >= hp.size() or hp[target] <= 0:
		return phases
	var remaining_hp := hp.duplicate()
	var focus := PackedInt32Array()
	focus.resize(hp.size())
	focus[target] = mini(damage, remaining_hp[target])
	remaining_hp[target] -= focus[target]
	damage -= focus[target]
	phases.append(focus)
	while damage > 0:
		var survivors: Array[int] = []
		for slot in range(remaining_hp.size()):
			if remaining_hp[slot] > 0:
				survivors.append(slot)
		if survivors.is_empty():
			break
		var share := damage / survivors.size()
		var remainder := damage % survivors.size()
		var spread := PackedInt32Array()
		spread.resize(hp.size())
		var unused := 0
		for index in range(survivors.size()):
			var slot := survivors[index]
			var assigned := share + int(index < remainder)
			var hit := mini(assigned, remaining_hp[slot])
			spread[slot] = hit
			remaining_hp[slot] -= hit
			unused += assigned - hit
		phases.append(spread)
		damage = unused
	return phases
