extends RefCounted

var ranks: Array[int] = [0, 0, 0, 0, 0, 0]
var lightning_hits := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func offer(maximum_rank: int) -> Array[int]:
	var pool: Array[int] = []
	var cards: Array[int] = []
	for card in range(ranks.size()):
		if ranks[card] < maximum_rank:
			pool.append(card)
	while cards.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		cards.append(pool[index])
		pool.remove_at(index)
	return cards


func resolve(damage: int, tuning: Resource) -> Dictionary:
	var amplified := roundi(damage * (1.0 + ranks[0] * tuning.attack_per_rank))
	var critical := ranks[1] > 0 and rng.randf() < minf(1.0, ranks[1] * tuning.critical_chance_per_rank)
	if critical:
		amplified = roundi(amplified * tuning.critical_multiplier)
	var ricochet := roundi(amplified * ranks[3] * tuning.ricochet_per_rank)
	var lightning := 0
	if ranks[2] > 0:
		lightning_hits += 1
		if lightning_hits >= maxi(1, tuning.lightning_hit_interval):
			lightning_hits = 0
			lightning = ranks[2] * tuning.lightning_damage_per_rank
	return {
		"total": amplified + ricochet + lightning,
		"critical": critical,
		"ricochet": ricochet,
		"lightning": lightning,
		"heal": ranks[4] * tuning.healing_per_rank,
	}
