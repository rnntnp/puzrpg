extends "res://scripts/gimmicks/handlers/circle_xpbd_pond_handler.gd"

const FormationConfig = preload("res://scripts/gimmicks/configs/pond_formation_config.gd")
const ActionIcons = preload("res://scripts/enemy_action_icons.gd")
const ACTION_PREVIEW_OFFSETS := [0, 3, 1, 2]
const Wave = preload("res://scripts/gimmicks/configs/formation_wave.gd")
const FormationVisual = preload("res://scripts/gimmicks/visuals/pond_formation_visual.gd")
const TurnAttackVisual = preload("res://scripts/gimmicks/visuals/pond_turn_attack_visual.gd")
const Allocation = preload("res://scripts/gimmicks/formation_damage.gd")
const DraftCards = preload("res://scripts/gimmicks/dungeon_draft_cards.gd")
const DraftVisual = preload("res://scripts/gimmicks/visuals/dungeon_draft_visual.gd")
const LINE_RIGHT_EDGE := 710.0

var formation: FormationConfig
var formation_visual: FormationVisual
var turn_attack_visual: TurnAttackVisual
var board_space := RID()
var board_space_was_active := false
var drop_started_msec := 0
var carried_merges := 0
var layout_index := 0
var action_preview_page := 0
var formation_locked := false
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
var previous_quiet_settlement_msec := 0
var player_anchor: Vector2
var original_enemy_position: Vector2
var enemy_ui: Array[CanvasItem] = []
var enemy_ui_visibility: Array[bool] = []


func _on_configured() -> void:
	formation = data.tuning as FormationConfig
	formation_visual = FormationVisual.new()
	battle.add_child(formation_visual)
	visual_layers.append(formation_visual)
	formation_visual.z_index = 2
	player_anchor = player.position
	original_enemy_position = enemy.position
	enemy_ui = [battle.right_fighter_shadow, battle.right_bar, battle.right_status_effects]
	for item in enemy_ui:
		enemy_ui_visibility.append(item.visible)
		item.hide()
	var layout_names := PackedStringArray()
	for layout in formation.layouts:
		layout_names.append(layout.display_name)
	layout_index = mini(layout_index, maxi(0, layout_names.size() - 1))
	formation_visual.add_layout_buttons(layout_names, layout_index)
	formation_visual.layout_selected.connect(_select_layout)
	action_preview_page = 1 if formation.preview_action_icons else 0
	formation_visual.add_action_preview_button()
	formation_visual.action_preview_pressed.connect(_cycle_action_preview)
	super._on_configured()
	_apply_layout()
	turn_attack_visual = attach_visual_layer(TurnAttackVisual.new()) as TurnAttackVisual
	turn_attack_visual.tuning = formation
	merge_game.player_merge_result_created.connect(turn_attack_visual.track_ball)
	previous_turn_gate = merge_game.wait_for_turn_before_next_input
	previous_quiet_settlement_msec = merge_game.merge_quiet_settlement_msec
	merge_game.wait_for_turn_before_next_input = true
	merge_game.merge_quiet_settlement_msec = roundi(formation.settlement_quiet_seconds * 1000.0)
	merge_game.player_merge_attack_collector = _collect_merge_attack
	if formation.draft != null:
		draft_visual = attach_visual_layer(DraftVisual.new())
		draft_visual.card_selected.connect(_select_card)
		_refresh_draft()


func _on_enemy_changed() -> void:
	super._on_enemy_changed()
	reserve_index = 0
	formation_locked = false
	formation_visual.set_layouts_locked(false)
	_spawn_wave()
	_update_status("전열 우선 · 같은 열에 균등 분배")
	if battle.current_enemy_index > 0 and is_instance_valid(draft_visual):
		_offer_cards()


func _current_wave() -> Wave:
	if not formation.layouts.is_empty():
		var preview := formation.layouts[layout_index].preview_wave
		if preview != null:
			return preview
	return formation.waves[battle.current_enemy_index]


func _spawn_wave() -> void:
	for fighter in front + rear:
		if is_instance_valid(fighter):
			formation_visual.remove_fighter(fighter)
	front.clear()
	rear.clear()
	var wave := _current_wave()
	var total_hp := 0
	for slot in wave.slots:
		total_hp += slot.health
		var column := front if slot.column == 0 else rear
		column.append(formation_visual.spawn(slot.character, slot.health, slot.attack, slot.position, formation.enemy_scale, _uses_joined_health_ui()))
	if formation.refill_slots:
		for reserve in wave.reinforcements:
			total_hp += reserve.health
	# The shared enemy tracks total remaining wave HP for stats and transitions.
	var wave_stats := enemy.character_data.duplicate() as CharacterData
	wave_stats.max_health = total_hp
	enemy.set_character_data(wave_stats)
	if is_instance_valid(player_visual):
		_apply_layout()
	enemy.hide()


func _on_player_ball_dropped() -> void:
	super._on_player_ball_dropped()
	drop_started_msec = Time.get_ticks_msec()
	if active and not formation_locked:
		formation_locked = true
		formation_visual.set_layouts_locked(true)


func _collect_merge_attack(damage: int, combo: int, _points: int, origin: Vector2, level: int, sequence: int) -> void:
	if not active or not battle.battle_running or not player.is_alive():
		return
	if not merge_game.drop_sequence_active:
		carried_merges += 1
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
	busy = true
	merge_game.set_input_enabled(false)
	var damage := pending_damage
	var settlement_msec := Time.get_ticks_msec()
	var settlement_seconds := float(settlement_msec - drop_started_msec) / 1000.0 if drop_started_msec > 0 else 0.0
	var carry_in := carried_merges
	carried_merges = 0
	battle.result_max_combo = maxi(battle.result_max_combo, pending_combo)
	pending_damage = 0
	pending_combo = 0
	var applied := Allocation.allocate(damage, _get_hp(front), _get_hp(rear))
	var hits: Array[Vector3i] = []
	for row in range(applied.size()):
		for slot in range(applied[row].size()):
			if applied[row][slot] > 0:
				hits.append(Vector3i(row, slot, applied[row][slot]))
	var spent := 0
	if not hits.is_empty():
		var origins := turn_attack_visual.take_origins()
		if origins.is_empty():
			origins.append(player.get_spell_origin_global_position())
		_pause_board_for_attack()
		player.play_cast_animation()
		spent = await _play_attack_hits(hits, origins, settlement_seconds)
		_restore_board_after_attack()
		if not active or not player.is_alive() or not battle.battle_running:
			return
	else:
		turn_attack_visual.take_origins()
		turn_attack_visual.finish_shots()
	var wave_cleared := spent >= enemy.current_health
	if spent > 0:
		enemy.take_damage(spent)
	if wave_cleared:
		_log_turn_timing(settlement_seconds, carry_in)
		return
	turns_remaining -= 1
	if turns_remaining <= 0:
		_counterattack()
		turns_remaining = maxi(1, enemy.enemy_attack_drop_interval)
		if formation.counterattack_seconds > 0.0 and player.is_alive():
			await get_tree().create_timer(formation.counterattack_seconds, false, false, true).timeout
		if not active or not player.is_alive() or not battle.battle_running:
			return
	if player.is_alive() and formation.refill_slots:
		_refill_empty_slots()
	busy = false
	_update_status("이번 턴 피해 %d · 적용 %d" % [damage, spent])
	merge_game.set_input_enabled(true)
	_log_turn_timing(settlement_seconds, carry_in)


func _play_attack_hits(hits: Array[Vector3i], origins: PackedVector2Array, settlement_seconds: float) -> int:
	var speed := clampf(settlement_seconds / formation.acceleration_after_seconds, 1.0, formation.maximum_attack_speed)
	var total := clampf(hits.size() * formation.seconds_per_target / speed,
		formation.minimum_attack_seconds, maxf(formation.minimum_attack_seconds, formation.maximum_attack_seconds))
	var beat := total / hits.size()
	var spent := 0
	for hit in hits:
		var column := front if hit.x == 0 else rear
		var fighter := column[hit.y]
		turn_attack_visual.start_shot(origins, fighter.character_sprite.global_position, hit.z, beat)
		await get_tree().create_timer(beat * TurnAttackVisual.TRAVEL_FRACTION, false, false, true).timeout
		if not active or not player.is_alive() or not battle.battle_running:
			break
		var defeated := hit.z >= fighter.current_health
		fighter.take_damage(hit.z, false)
		turn_attack_visual.show_impact(fighter, hit.z, defeated)
		spent += hit.z
		if not fighter.is_alive():
			formation_visual.retire_defeated_fighter(fighter, formation.impact_flash_seconds)
			column[hit.y] = null
		await get_tree().create_timer(beat * (1.0 - TurnAttackVisual.TRAVEL_FRACTION), false, false, true).timeout
		if not active or not player.is_alive() or not battle.battle_running:
			break
	if is_instance_valid(turn_attack_visual):
		turn_attack_visual.finish_shots()
	return spent


func _pause_board_for_attack() -> void:
	board_space = merge_game.get_world_2d().space
	board_space_was_active = PhysicsServer2D.space_is_active(board_space)
	merge_game.attack_presentation_paused = true
	PhysicsServer2D.space_set_active(board_space, false)


func _restore_board_after_attack() -> void:
	if not board_space.is_valid():
		return
	PhysicsServer2D.space_set_active(board_space, board_space_was_active)
	board_space = RID()
	if is_instance_valid(merge_game):
		merge_game.attack_presentation_paused = false


func _log_turn_timing(settlement_seconds: float, carry_in: int) -> void:
	var total_seconds := float(Time.get_ticks_msec() - drop_started_msec) / 1000.0 if drop_started_msec > 0 else 0.0
	print("[FORMATION TURN] settle=%.3fs total=%.3fs carried_in=%d late_merges=%d" % [
		settlement_seconds, total_seconds, carry_in, carried_merges,
	])


func _get_hp(column: Array[Fighter]) -> Array[int]:
	var hp: Array[int] = []
	for fighter in column:
		hp.append(fighter.current_health if is_instance_valid(fighter) else 0)
	return hp


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
	var wave := _current_wave()
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
		column[index] = formation_visual.spawn(reserve.character, reserve.health, reserve.attack, slot.position, formation.enemy_scale, _uses_joined_health_ui())
	_apply_layout()


func _uses_joined_health_ui() -> bool:
	return not formation.layouts.is_empty() and formation.layouts[layout_index].preview_wave != null


func _select_layout(index: int) -> void:
	if not active or busy or formation_locked or index == layout_index or index < 0 or index >= formation.layouts.size():
		return
	var previous_wave := _current_wave()
	layout_index = index
	if _current_wave() == previous_wave:
		_apply_layout()
	else:
		reserve_index = 0
		_spawn_wave()


func _apply_layout() -> void:
	var layout := formation.layouts[layout_index] if not formation.layouts.is_empty() else null
	var wave := _current_wave()
	var ordered_slots: Array = []
	for column_index in range(2):
		for slot in wave.slots:
			if slot.column == column_index:
				ordered_slots.append(slot)
	var size_factor := formation.enemy_scale * (layout.sprite_scale_multiplier if layout != null else 1.0)
	var positions := PackedVector2Array()
	var sizes := PackedFloat32Array()
	if layout != null and layout.use_staggered_line:
		var line := _line_positions(ordered_slots, size_factor, layout)
		positions = line.positions
		sizes = line.sizes
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
		var fighter_size := size_factor
		var foot_y := at.y
		var draw_order_offset := 0
		if layout != null:
			at = positions[index] if layout.use_staggered_line else layout.slot_position(at, slot.column, row, column.size())
			foot_y = at.y
			if layout.use_staggered_line:
				fighter_size = sizes[index]
				var slot_character: CharacterData = slot.character
				var slot_span := formation_visual.sprite_span(slot_character, fighter_size)
				var actual_span := formation_visual.sprite_span(fighter.character_data, 1.0)
				fighter_size = minf(fighter_size, (slot_span.y - slot_span.x) / maxf(1.0, actual_span.y - actual_span.x))
				at.x += slot_span.x - actual_span.x * fighter_size
				at.y -= formation_visual.sprite_vertical_span(fighter.character_data).y * fighter_size
			if index < layout.slot_offsets.size():
				at += layout.slot_offsets[index]
				foot_y += layout.slot_offsets[index].y
			if index < layout.info_offsets.size():
				info_offset += layout.info_offsets[index]
			if index < layout.draw_order_offsets.size():
				draw_order_offset = layout.draw_order_offsets[index]
		var anchor := fighter.get_parent() as Node2D
		anchor.position = at
		anchor.z_index = (100 if slot.column == 0 else 0) + maxi(0, 90 - index) + draw_order_offset
		fighter.base_scale = Vector2.ONE * fighter_size
		fighter.scale = fighter.base_scale
		var shadow_offset := Vector2.ZERO
		var shadow_scale := Vector2.ONE
		if layout != null:
			if index < layout.shadow_offsets.size():
				shadow_offset = layout.shadow_offsets[index]
			if index < layout.shadow_scale_multipliers.size():
				shadow_scale = layout.shadow_scale_multipliers[index]
		formation_visual.position_info(fighter, at, info_offset)
		formation_visual.position_shadow(fighter, foot_y - at.y, layout != null and layout.show_shadows, shadow_offset, shadow_scale)
		if aim_at == Vector2.INF:
			aim_at = at
	if aim_at != Vector2.INF:
		enemy.position = aim_at
	formation_visual.reflow_info()
	_update_action_previews()


func _line_left_edge() -> float:
	var player_bounds: Rect2 = player_visual.resting_bounds
	return player_anchor.x + player_bounds.end.x * player.base_scale.x + formation.player_enemy_gap


func _line_positions(ordered_slots: Array, size_factor: float, layout: Resource) -> Dictionary:
	var positions := PackedVector2Array()
	var sizes := PackedFloat32Array()
	var player_bounds: Rect2 = player_visual.resting_bounds
	var player_height: float = player_bounds.size.y * player.base_scale.y
	var baseline: float = player_anchor.y + player_bounds.end.y * player.base_scale.y + layout.line_height_offset
	var edge := 0.0
	var previous_width := 0.0
	var widest := 0.0
	var spans: Array[Vector2] = []
	var gaps: float = layout.horizontal_spacing * maxi(0, ordered_slots.size() - 1)
	for index in range(ordered_slots.size()):
		var character: CharacterData = ordered_slots[index].character
		var slot_size := size_factor
		if layout.enemy_height_ratio > 0.0:
			var bounds := formation_visual.sprite_vertical_span(character)
			slot_size = player_height * layout.enemy_height_ratio / maxf(1.0, bounds.y - bounds.x)
		if index < layout.slot_scale_multipliers.size():
			slot_size *= layout.slot_scale_multipliers[index]
		var span := formation_visual.sprite_span(character, slot_size)
		var width := span.y - span.x
		spans.append(span)
		widest = maxf(widest, width)
		edge -= minf(previous_width, width) * layout.overlap_ratio
		var row_offset := (ordered_slots.size() - 1) * 0.5 - index
		positions.append(Vector2(edge - span.x, baseline + row_offset * layout.line_rise))
		sizes.append(slot_size)
		edge += width
		previous_width = width
	if layout.alternating_lift > 0.0 and positions.size() > 1:
		var intervals := positions.size() - 1
		var available := LINE_RIGHT_EDGE - _line_left_edge()
		# Reserve horizontal clearance between every other slot, which shares a height band.
		var width_limit := minf(available, (2.0 * available - gaps) / (intervals + 2.0))
		var stagger_fit := minf(1.0, maxf(1.0, width_limit) / maxf(1.0, widest))
		var half_width := widest * stagger_fit * 0.5
		for index in range(positions.size()):
			var center := lerpf(_line_left_edge() + half_width, LINE_RIGHT_EDGE - half_width, float(index) / intervals)
			positions[index].x = center - (spans[index].x + spans[index].y) * stagger_fit * 0.5
			positions[index].y -= (index % 2) * layout.alternating_lift
			sizes[index] *= stagger_fit
		return {"positions": positions, "sizes": sizes}
	var fit := minf(1.0, maxf(1.0, LINE_RIGHT_EDGE - _line_left_edge() - gaps) / maxf(edge, 1.0))
	var start := LINE_RIGHT_EDGE - edge * fit - gaps
	for index in range(positions.size()):
		positions[index].x = start + positions[index].x * fit + index * layout.horizontal_spacing
		sizes[index] *= fit
	return {"positions": positions, "sizes": sizes}


func _refresh() -> void:
	_update_status(last_effect)


func _process(_delta: float) -> void:
	if active and is_instance_valid(formation_visual):
		formation_visual.set_effect_state(battle.monster_action_controller.vulnerable_turns, weaken)


func _update_status(detail: String) -> void:
	battle.enemy_progress_label.text = "WAVE %d / %d%s" % [
		battle.current_enemy_index + 1, formation.waves.size(), " · 충원" if formation.refill_slots else ""
	]
	_update_action_previews()
	battle.update_gimmick_ui("", detail)


func _update_action_previews() -> void:
	formation_visual.real_attack_turns = turns_remaining
	var demo := action_preview_page > 0
	var offset: int = ACTION_PREVIEW_OFFSETS[action_preview_page - 1] if demo else 0
	formation_visual.set_action_preview_page(action_preview_page, ACTION_PREVIEW_OFFSETS.size())
	var preview_turns := [3, 2, 1]
	var slot_index := 0
	for fighter in front + rear:
		if is_instance_valid(fighter):
			var kind: int = ActionIcons.Kind.ATTACK
			var turns := turns_remaining
			if demo:
				kind = (offset + slot_index) % ActionIcons.Kind.size()
				turns = preview_turns[slot_index % preview_turns.size()]
			formation_visual.set_action_preview(fighter, kind, turns, demo)
		slot_index += 1


func _cycle_action_preview() -> void:
	action_preview_page = (action_preview_page + 1) % (ACTION_PREVIEW_OFFSETS.size() + 1)
	_update_status(battle.gimmick_detail_label.text)


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
	_restore_board_after_attack()
	if is_instance_valid(merge_game):
		if is_instance_valid(turn_attack_visual) and merge_game.player_merge_result_created.is_connected(turn_attack_visual.track_ball):
			merge_game.player_merge_result_created.disconnect(turn_attack_visual.track_ball)
		merge_game.player_merge_attack_collector = Callable()
		merge_game.wait_for_turn_before_next_input = previous_turn_gate
		merge_game.merge_quiet_settlement_msec = previous_quiet_settlement_msec
	if is_instance_valid(enemy):
		enemy.position = original_enemy_position
	for index in range(enemy_ui.size()):
		if is_instance_valid(enemy_ui[index]):
			enemy_ui[index].visible = enemy_ui_visibility[index]
	super._on_cleanup()


func _exit_tree() -> void:
	_release_pause()
	_restore_board_after_attack()
