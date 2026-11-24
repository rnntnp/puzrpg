extends RefCounted


@warning_ignore("integer_division")
static func allocate(damage: int, target: int, hp: Array[int], redirects: Dictionary[int, int] = {},
		shotgun_multiplier := 1.0, vulnerable_slot := -1, vulnerability := 1.0) -> Array[PackedInt32Array]:
	var phases: Array[PackedInt32Array] = []
	if damage <= 0 or target < 0 or target >= hp.size() or hp[target] <= 0:
		return phases
	var remaining_hp := hp.duplicate()
	var focus := PackedInt32Array()
	focus.resize(hp.size())
	var receiver := damage_receiver(target, remaining_hp, redirects)
	var multiplier := vulnerability if receiver == vulnerable_slot else 1.0
	focus[target] = mini(roundi(damage * multiplier), remaining_hp[receiver])
	remaining_hp[receiver] -= focus[target]
	damage = roundi((damage - _spent_budget(focus[target], multiplier)) * shotgun_multiplier)
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
		var phase_hp := remaining_hp.duplicate()
		for index in range(survivors.size()):
			var slot := survivors[index]
			var assigned := share + int(index < remainder)
			receiver = damage_receiver(slot, phase_hp, redirects)
			multiplier = vulnerability if receiver == vulnerable_slot else 1.0
			var hit := mini(roundi(assigned * multiplier), remaining_hp[receiver])
			spread[slot] = hit
			remaining_hp[receiver] -= hit
			unused += assigned - _spent_budget(hit, multiplier)
		phases.append(spread)
		damage = unused
	return phases


static func _spent_budget(hit: int, multiplier: float) -> int:
	return ceili((hit - 0.5) / multiplier)


static func damage_receiver(slot: int, hp: Array[int], redirects: Dictionary[int, int]) -> int:
	var protector: int = redirects.get(slot, slot)
	return protector if hp[protector] > 0 else slot
