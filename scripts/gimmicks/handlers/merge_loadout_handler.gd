extends TestGimmickHandler

const Store = preload("res://scripts/gimmicks/merge_loadout_store.gd")
const Config = preload("res://scripts/gimmicks/configs/merge_loadout_config.gd")
const Launcher = preload("res://scripts/gimmicks/visuals/merge_loadout_launcher.gd")

var tuning: Resource
var slots: Array[int] = []
var launcher: Node2D
var shield := 0
var weaken := 0.0
var focus: Array[float] = []
var turns_remaining := 3
var last_effect := "아래 발사구에서 위쪽 방향을 정한 뒤 놓으면 고정된 힘으로 발사"

func _on_configured() -> void:
	tuning = data.tuning if data.tuning != null else Config.new()
	slots = Store.read_slots()
	launcher = attach_visual_layer(Launcher.new())
	launcher.configure(merge_game, tuning)
	merge_game.player_merge_damage_modifier = _resolve_merge
	_on_enemy_changed()

func _on_enemy_changed() -> void:
	weaken = 0.0
	shield = 0
	focus.clear()
	turns_remaining = maxi(1, enemy.enemy_attack_drop_interval)
	_refresh()

func _resolve_merge(damage: int, source_stage: int) -> int:
	if not active or not player.is_alive() or not enemy.is_alive():
		return damage
	var bonus := 0.0
	if not focus.is_empty():
		bonus = focus.pop_front()
	var ability: int = slots[source_stage - 1] if source_stage >= 1 and source_stage <= slots.size() else 0
	match ability:
		1: bonus += tuning.strong_base + source_stage * tuning.strong_per_stage
		2: shield = mini(tuning.guard_cap, shield + tuning.guard_base + source_stage * tuning.guard_per_stage)
		3:
			if focus.size() < tuning.focus_cap:
				focus.append(tuning.focus_base + source_stage * tuning.focus_per_stage)
		4: weaken = maxf(weaken, minf(tuning.weaken_cap, tuning.weaken_base + source_stage * tuning.weaken_per_stage))
	last_effect = "%d + %d → %d · %s" % [source_stage, source_stage, source_stage + 1, Store.NAMES[ability]]
	_refresh()
	return roundi(damage * (1.0 + bonus))


func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	turns_remaining -= 1
	if turns_remaining <= 0:
		var reduced := roundi(enemy.attack_power * (1.0 - weaken))
		var received := maxi(0, reduced - shield)
		last_effect = "적 공격 %d → 쇠약·보호막 적용 → 피해 %d" % [enemy.attack_power, received]
		shield = 0
		weaken = 0.0
		enemy.attack_with_damage(player, received)
		turns_remaining = maxi(1, enemy.enemy_attack_drop_interval)
	_refresh()

func _refresh() -> void:
	var loadout := ""
	for index in range(slots.size()):
		if slots[index] != 0:
			loadout += "%d:%s " % [index + 1, Store.NAMES[slots[index]]]
	battle.update_gimmick_ui("반격 %d턴 · 보호막 %d · 집중 %d · 쇠약 %d%%" % [turns_remaining, shield, focus.size(), roundi(weaken * 100)], loadout + "\n" + last_effect)
	battle.show_player_damage_preview(maxi(0, roundi(enemy.attack_power * (1.0 - weaken)) - shield))

func _on_cleanup() -> void:
	if is_instance_valid(merge_game):
		merge_game.player_merge_damage_modifier = Callable()
		merge_game.player_merge_velocity_modifier = Callable()
	if is_instance_valid(launcher):
		launcher.restore_input()
	battle.clear_player_damage_preview()
	shield = 0
	weaken = 0.0
	focus.clear()
