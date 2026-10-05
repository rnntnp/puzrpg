extends TestGimmickHandler

const Config = preload("res://scripts/gimmicks/configs/dungeon_draft_config.gd")
const Visual = preload("res://scripts/gimmicks/visuals/dungeon_draft_visual.gd")

var tuning: Resource
var visual: Node2D
var ranks: Array[int] = [0, 0, 0, 0, 0, 0]
var offered: Array[int] = []
var rng := RandomNumberGenerator.new()
var turns_remaining := 4
var lightning_hits := 0
var reward_wave := -1
var owns_pause := false
var last_effect := "가로 위치를 정해 놓기 · 같은 단계 합성 → 자동 공격"

func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else Config.new()
	rng.randomize()
	visual = attach_visual_layer(Visual.new())
	visual.card_selected.connect(_select_card)
	enemy.health_changed.connect(_on_enemy_health_changed)
	_on_enemy_changed()

func _on_enemy_changed() -> void:
	var wave := battle.current_enemy_index
	turns_remaining = _interval()
	# Battle duplicates this Resource before handing it to a test handler.
	enemy.character_data.display_name = str(tuning.wave_names[mini(wave, tuning.wave_names.size() - 1)])
	last_effect = "%d연쇄 이상이면 갑옷 무시" % tuning.armor_bypass_chain if _armored() else "합성해 공격하고 다음 웨이브의 카드를 획득하세요"
	_refresh()
	if wave > 0 and reward_wave != wave:
		_offer_cards()

func _offer_cards() -> void:
	offered.clear()
	var pool: Array[int] = []
	for card in range(ranks.size()):
		if ranks[card] < tuning.maximum_rank:
			pool.append(card)
	while offered.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		offered.append(pool[index])
		pool.remove_at(index)
	if offered.is_empty():
		return
	busy = true
	merge_game.set_input_enabled(false)
	visual.show_choices(offered, ranks, tuning, battle.current_enemy_index, battle.level_data.enemies.size())
	# The board, delayed projectiles and Danger Line all pause together.
	# The mechanic-owned modal alone processes input while paused.
	owns_pause = not get_tree().paused
	get_tree().paused = true

func _select_card(card: int) -> void:
	if not active or not busy or card not in offered or not player.is_alive():
		return
	ranks[card] += 1
	reward_wave = battle.current_enemy_index
	last_effect = "%s Lv.%d 획득 · %s" % [Config.CARD_NAMES[card], ranks[card], tuning.card_description(card, ranks[card])]
	offered.clear()
	visual.hide_choices()
	busy = false
	_release_pause()
	_refresh()
	if battle.battle_running and enemy.is_alive():
		merge_game.set_input_enabled(true)

func modify_player_damage(damage: int, _result_level := -1, combo_count := 1, _origin := Vector2.ZERO) -> int:
	if not active or busy or damage <= 0 or not player.is_alive() or not enemy.is_alive():
		return damage
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
	var total := amplified + ricochet + lightning
	var blocked: bool = _armored() and combo_count < tuning.armor_bypass_chain
	if blocked:
		total = maxi(1, roundi(total * tuning.armor_multiplier))
	if ranks[4] > 0:
		player.heal(ranks[4] * tuning.healing_per_rank)
	# Bonuses share the original hit, preserving damage stats, Weakness routing
	# and enemy-death ownership. They never register another merge or gauge gain.
	visual.show_hit(enemy.global_position, critical, lightning, ricochet, blocked)
	last_effect = "%d연쇄 · 피해 %d%s%s" % [combo_count, total, " · 치명타!" if critical else "", " · 갑옷 적용" if blocked else ""]
	_refresh()
	return total

func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	turns_remaining -= 1
	if turns_remaining <= 0:
		var incoming := _incoming_damage()
		last_effect = "반격 %d 피해 · 돌가죽 %d 감소" % [incoming, ranks[5] * tuning.guard_per_rank]
		enemy.attack_with_damage(player, incoming)
		turns_remaining = _interval()
	_refresh()

func _interval() -> int:
	return maxi(1, tuning.wave_intervals[mini(battle.current_enemy_index, tuning.wave_intervals.size() - 1)])

func _armored() -> bool:
	return battle.current_enemy_index == 2 or battle.current_enemy_index == battle.level_data.enemies.size() - 1

func _enraged() -> bool:
	return battle.current_enemy_index == battle.level_data.enemies.size() - 1 and enemy.current_health <= enemy.max_health * tuning.boss_enrage_health_ratio

func _on_enemy_health_changed(health: int, _maximum: int) -> void:
	if active and health > 0 and is_instance_valid(visual):
		_refresh()

func _incoming_damage() -> int:
	var damage: int = tuning.wave_damage[mini(battle.current_enemy_index, tuning.wave_damage.size() - 1)]
	if _enraged():
		damage = roundi(damage * tuning.boss_enrage_multiplier)
	return maxi(0, damage - ranks[5] * tuning.guard_per_rank)

func _refresh() -> void:
	var wave := battle.current_enemy_index
	battle.enemy_progress_label.text = "WAVE %d / %d · %s" % [wave + 1, battle.level_data.enemies.size(), enemy.display_name]
	var enemy_rule := " · %d연쇄로 갑옷 관통" % tuning.armor_bypass_chain if _armored() else ""
	if _enraged():
		enemy_rule += " · 분노"
	battle.update_gimmick_ui("반격 %d턴 / %d 피해%s" % [turns_remaining, _incoming_damage(), enemy_rule], last_effect)
	battle.show_player_damage_preview(_incoming_damage())
	visual.update_build(ranks, lightning_hits, tuning)

func _release_pause() -> void:
	if owns_pause and is_inside_tree():
		get_tree().paused = false
	owns_pause = false

func _on_cleanup() -> void:
	_release_pause()
	offered.clear()
	if is_instance_valid(enemy) and enemy.health_changed.is_connected(_on_enemy_health_changed):
		enemy.health_changed.disconnect(_on_enemy_health_changed)
	if is_instance_valid(battle):
		battle.clear_player_damage_preview()

func _exit_tree() -> void:
	# Scene replacement also releases a modal pause, even without cleanup().
	_release_pause()
