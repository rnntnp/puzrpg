extends "res://scripts/gimmicks/handlers/circle_xpbd_pond_handler.gd"

const FormationConfig = preload("res://scripts/gimmicks/configs/pond_formation_config.gd")
const FormationVisual = preload("res://scripts/gimmicks/visuals/pond_formation_visual.gd")
const Allocation = preload("res://scripts/gimmicks/formation_damage.gd")
const DraftCards = preload("res://scripts/gimmicks/dungeon_draft_cards.gd")
const DraftVisual = preload("res://scripts/gimmicks/visuals/dungeon_draft_visual.gd")

var formation: FormationConfig
var formation_visual: FormationVisual
var layout_index := 0
var draft_visual: Node2D
var cards := DraftCards.new()
var offered: Array[int] = []
var front: Array[Fighter] = []
var rear: Array[Fighter] = []
var reserve_index := 0
var pending_damage := 0
var pending_combo := 0
var owns_pause := false
var previous_turn_gate := false
var original_player_position: Vector2
var original_player_scale: Vector2
var original_player_shadow_position: Vector2
var original_player_shadow_scale: Vector2
var original_enemy_position: Vector2
var enemy_ui: Array[CanvasItem] = []
var enemy_ui_visibility: Array[bool] = []


func _on_configured() -> void:
	formation = data.tuning as FormationConfig
	formation_visual = FormationVisual.new()
	battle.add_child(formation_visual)
	visual_layers.append(formation_visual)
	formation_visual.z_index = 2
	original_player_position = player.position
	original_player_scale = player.base_scale
	original_player_shadow_position = battle.left_fighter_shadow.position
	original_player_shadow_scale = battle.left_fighter_shadow.scale
	original_enemy_position = enemy.position
	player.position = formation.player_position
	player.base_scale = Vector2.ONE * formation.player_scale
	player.scale = player.base_scale
	var shadow_ratio := formation.player_scale / original_player_scale.x
	battle.left_fighter_shadow.position = player.position + (original_player_shadow_position - original_player_position) * shadow_ratio
	battle.left_fighter_shadow.scale = original_player_shadow_scale * shadow_ratio
	enemy_ui = [battle.right_fighter_shadow, battle.right_bar, battle.right_status_effects]
	for item in enemy_ui:
		enemy_ui_visibility.append(item.visible)
		item.hide()
	var layout_names := PackedStringArray()
	for layout in formation.layouts:
		layout_names.append(layout.display_name)
	formation_visual.add_layout_buttons(layout_names)
	formation_visual.layout_selected.connect(_select_layout)
	super._on_configured()
	previous_turn_gate = merge_game.wait_for_turn_before_next_input
	merge_game.wait_for_turn_before_next_input = true
	merge_game.player_merge_attack_collector = _collect_merge_attack
	if formation.draft != null:
		draft_visual = attach_visual_layer(DraftVisual.new())
		draft_visual.card_selected.connect(_select_card)
		_refresh_draft()


func _on_enemy_changed() -> void:
	super._on_enemy_changed()
	pending_damage = 0
	pending_combo = 0
	reserve_index = 0
	front.clear()
	rear.clear()
	var wave := formation.waves[battle.current_enemy_index]
	var total_hp := 0
	for slot in wave.slots:
		total_hp += slot.health
		var column := front if slot.column == 0 else rear
		column.append(formation_visual.spawn(slot.character, slot.health, slot.attack, slot.position, formation.enemy_scale))
	if formation.refill_slots:
		for reserve in wave.reinforcements:
			total_hp += reserve.health
	# The shared enemy tracks total remaining wave HP for stats and transitions.
	var wave_stats := enemy.character_data.duplicate() as CharacterData
	wave_stats.max_health = total_hp
	enemy.set_character_data(wave_stats)
	_apply_layout()
	enemy.hide()
	_update_status("전열 우선 · 같은 열에 균등 분배")
	if battle.current_enemy_index > 0 and is_instance_valid(draft_visual):
		_offer_cards()


func _collect_merge_attack(damage: int, combo: int, _points: int, origin: Vector2, level: int, sequence: int) -> void:
	if not active or busy or not battle.battle_running or not player.is_alive() or not enemy.is_alive():
		return
	damage = battle.monster_action_controller.route_player_damage(damage, level, combo, origin, sequence)
	if damage <= 0:
		return
	pending_damage += damage
	pending_combo = maxi(pending_combo, combo)



func modify_player_damage(damage: int, _level := -1, _combo := 1, _origin := Vector2.ZERO) -> int:
	if formation.draft == null:
		return damage
	var bonus := cards.resolve(damage, formation.draft)
	player.heal(bonus["heal"])
	_refresh_draft()
	return bonus["total"]

func on_turn_completed() -> void:
	if not active or busy or not enemy.is_alive() or not player.is_alive():
		return
	var damage := pending_damage
	battle.result_max_combo = maxi(battle.result_max_combo, pending_combo)
	pending_damage = 0
	pending_combo = 0
	var applied := Allocation.allocate(damage, _get_hp(front), _get_hp(rear))
	var spent := _apply_hits(front, applied[0]) + _apply_hits(rear, applied[1])
	if spent > 0:
		player.play_cast_animation()
	var wave_cleared := spent >= enemy.current_health
	if wave_cleared:
		busy = true
	if spent > 0:
		enemy.take_damage(spent)
	if wave_cleared:
		return
	turns_remaining -= 1
	if turns_remaining <= 0:
		_counterattack()
		turns_remaining = maxi(1, enemy.enemy_attack_drop_interval)
	if player.is_alive() and formation.refill_slots:
		_refill_empty_slots()
	_update_status("이번 턴 피해 %d · 적용 %d" % [damage, spent])


func _get_hp(column: Array[Fighter]) -> Array[int]:
	var hp: Array[int] = []
	for fighter in column:
		hp.append(fighter.current_health if is_instance_valid(fighter) else 0)
	return hp


func _apply_hits(column: Array[Fighter], hits: PackedInt32Array) -> int:
	var spent := 0
	for index in range(column.size()):
		if hits[index] <= 0:
			continue
		var fighter := column[index]
		fighter.take_damage(hits[index])
		spent += hits[index]
		if not fighter.is_alive():
			fighter.hide()
			fighter.get_meta("formation_info").hide()
			fighter.get_parent().queue_free()
			column[index] = null
	return spent


func _counterattack() -> void:
	var guard := shield
	if formation.draft != null:
		guard += cards.ranks[5] * formation.draft.guard_per_rank
	for column in [front, rear]:
		for fighter: Fighter in column:
			if not player.is_alive():
				return
			if not is_instance_valid(fighter):
				continue
			var hit := roundi(fighter.attack_power * (1.0 - weaken))
			fighter.attack_with_damage(player, maxi(0, hit - guard))
			guard = maxi(0, guard - hit)
	shield = 0
	weaken = 0.0


func _refill_empty_slots() -> void:
	var wave := formation.waves[battle.current_enemy_index]
	var column_indices := [0, 0]
	for slot in wave.slots:
		var column := front if slot.column == 0 else rear
		var index: int = column_indices[slot.column]
		column_indices[slot.column] += 1
		if is_instance_valid(column[index]):
			continue
		if reserve_index >= wave.reinforcements.size():
			break
		var reserve := wave.reinforcements[reserve_index]
		reserve_index += 1
		column[index] = formation_visual.spawn(reserve.character, reserve.health, reserve.attack, slot.position, formation.enemy_scale)
	_apply_layout()


func _select_layout(index: int) -> void:
	if not active or index < 0 or index >= formation.layouts.size():
		return
	layout_index = index
	_apply_layout()


func _apply_layout() -> void:
	var layout := formation.layouts[layout_index] if not formation.layouts.is_empty() else null
	var wave := formation.waves[battle.current_enemy_index]
	var ordered_slots: Array = []
	for column_index in range(2):
		for slot in wave.slots:
			if slot.column == column_index:
				ordered_slots.append(slot)
	var size_factor := formation.enemy_scale * (layout.sprite_scale_multiplier if layout != null else 1.0)
	var positions := PackedVector2Array()
	if layout != null and layout.use_staggered_line:
		var line := _line_positions(ordered_slots, size_factor, layout)
		positions = line.positions
		size_factor *= line.fit
	var row_indices := [0, 0]
	var aim_at := Vector2.INF
	for index in range(ordered_slots.size()):
		var slot = ordered_slots[index]
		var column := front if slot.column == 0 else rear
		var row: int = row_indices[slot.column]
		row_indices[slot.column] += 1
		var fighter := column[row]
		if not is_instance_valid(fighter):
			continue
		var at: Vector2 = slot.position
		var info_offset := Vector2.ZERO
		if layout != null:
			at = positions[index] if layout.use_staggered_line else layout.slot_position(at, slot.column, row, column.size())
			if index < layout.slot_offsets.size():
				at += layout.slot_offsets[index]
			if index < layout.info_offsets.size():
				info_offset = layout.info_offsets[index]
		var anchor := fighter.get_parent() as Node2D
		anchor.position = at
		anchor.z_index = (100 if slot.column == 0 else 0) + clampi(roundi(at.y / 6.0), 0, 90)
		fighter.base_scale = Vector2.ONE * size_factor
		fighter.scale = fighter.base_scale
		formation_visual.position_info(fighter, at, info_offset)
		if aim_at == Vector2.INF:
			aim_at = at
	if aim_at != Vector2.INF:
		enemy.position = aim_at


func _line_positions(ordered_slots: Array, size_factor: float, layout: Resource) -> Dictionary:
	var positions := PackedVector2Array()
	var edge := 0.0
	var previous_width := 0.0
	for index in range(ordered_slots.size()):
		var span := formation_visual.sprite_span(ordered_slots[index].character, size_factor)
		var width := span.y - span.x
		edge -= minf(previous_width, width) * layout.overlap_ratio
		positions.append(Vector2(edge - span.x, layout.line_height - index * layout.line_rise))
		edge += width
		previous_width = width
	var fit := minf(1.0, 395.0 / maxf(edge, 1.0))
	var start := 710.0 - edge * fit
	for index in range(positions.size()):
		positions[index].x = start + positions[index].x * fit
	return {"positions": positions, "fit": fit}


func _refresh() -> void:
	_update_status(last_effect)


func _update_status(detail: String) -> void:
	battle.enemy_progress_label.text = "WAVE %d / %d%s" % [
		battle.current_enemy_index + 1, formation.waves.size(), " · 충원" if formation.refill_slots else ""
	]
	battle.update_gimmick_ui("적 반격까지 %d턴" % turns_remaining, detail)


func _offer_cards() -> void:
	offered = cards.offer(formation.draft.maximum_rank)
	if offered.is_empty():
		return
	busy = true
	merge_game.set_input_enabled(false)
	draft_visual.show_choices(offered, cards.ranks, formation.draft, battle.current_enemy_index, formation.waves.size())
	owns_pause = not get_tree().paused
	get_tree().paused = true


func _select_card(card: int) -> void:
	if not offered.has(card) or not player.is_alive():
		return
	cards.ranks[card] += 1
	offered.clear()
	draft_visual.hide_choices()
	busy = false
	_refresh_draft()
	_release_pause()
	if battle.battle_running and enemy.is_alive():
		merge_game.set_input_enabled(true)


func _refresh_draft() -> void:
	draft_visual.update_build(cards.ranks, cards.lightning_hits, formation.draft)


func _release_pause() -> void:
	if owns_pause and is_inside_tree():
		get_tree().paused = false
	owns_pause = false


func _on_cleanup() -> void:
	_release_pause()
	if is_instance_valid(merge_game):
		merge_game.player_merge_attack_collector = Callable()
		merge_game.wait_for_turn_before_next_input = previous_turn_gate
	if is_instance_valid(enemy):
		enemy.position = original_enemy_position
	if is_instance_valid(player):
		player.position = original_player_position
		player.base_scale = original_player_scale
		player.scale = original_player_scale
		battle.left_fighter_shadow.position = original_player_shadow_position
		battle.left_fighter_shadow.scale = original_player_shadow_scale
	for index in range(enemy_ui.size()):
		if is_instance_valid(enemy_ui[index]):
			enemy_ui[index].visible = enemy_ui_visibility[index]
	super._on_cleanup()


func _exit_tree() -> void:
	_release_pause()
