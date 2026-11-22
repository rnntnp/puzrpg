extends Node2D

signal layout_selected(index: int)
signal action_preview_pressed
signal enemy_clicked(fighter: Fighter)

var info_layer := Node2D.new()
var opaque_bounds: Dictionary = {}
var layout_buttons: Array[Button] = []
var action_preview_button: Button
var weakness_turns := 0
var attack_reduction := 0.0
var fighters: Dictionary[WaterHealthBar, Fighter] = {}
var selected_enemy: Fighter
var marked_enemy: Fighter
var target_marker: Polygon2D
var captured_pointer := -2
var detail_panel: EnemyDetails
var real_attack_turns := 0
var reduction_effect: StatusEffectData

const FighterScene = preload("res://scenes/fighter.tscn")
const HealthBarScene = preload("res://scenes/water_health_bar.tscn")
const ActionIcons = preload("res://scripts/enemy_action_icons.gd")
const EnemyDetails = preload("res://scripts/gimmicks/visuals/formation_enemy_details.gd")
const WEAKNESS_EFFECT = preload("res://resources/effects/ingestion_vulnerable.tres")
const DETAIL_FONT = preload("res://assets/fonts/nanum_square_round/NanumSquareRoundEB.ttf")
const HEALTH_BAR_SCALE := 0.35
const JOINED_HEALTH_SCALE := 0.49
const INFO_BOUNDS := Vector2(154, 81)
const BAR_OFFSET := Vector2(52, 54)


func _ready() -> void:
	info_layer.z_index = 200
	add_child(info_layer)
	target_marker = Polygon2D.new()
	target_marker.z_index = 205
	target_marker.hide()
	add_child(target_marker)
	reduction_effect = WEAKNESS_EFFECT.duplicate()
	reduction_effect.effect_id = &"formation_attack_reduction"
	reduction_effect.display_name = "공격력 감소"
	reduction_effect.icon_modulate = Color(1.0, 0.72, 0.62)
	reduction_effect.show_turns = false
	_create_detail_panel()


func spawn(character: CharacterData, health: int, attack: int, at: Vector2, size_factor: float, joined_health_ui: bool) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	var stats := character.duplicate() as CharacterData
	stats.max_health = maxi(1, health)
	stats.attack_power = attack
	fighter.character_data = stats
	var anchor := Node2D.new()
	anchor.position = at
	fighter.scale = Vector2.ONE * size_factor
	anchor.add_child(fighter)
	add_child(anchor)
	_add_health_bar(fighter, joined_health_ui)
	return fighter


func remove_fighter(fighter: Fighter) -> void:
	if fighter == selected_enemy:
		_close_details()
	fighter.get_parent().hide()
	fighter.get_meta("formation_info").hide()
	fighter.get_parent().queue_free()


func retire_defeated_fighter(fighter: Fighter, flash_seconds: float) -> void:
	if fighter == selected_enemy:
		_close_details()
	fighter.get_meta("formation_info").hide()
	if fighter == marked_enemy:
		target_marker.hide()
	await get_tree().create_timer(flash_seconds, false).timeout
	if not is_instance_valid(fighter):
		return
	await fighter.play_defeat_animation(0.17)
	if is_instance_valid(fighter):
		fighter.get_parent().queue_free()


func add_layout_buttons(layout_names: PackedStringArray, selected_index: int) -> void:
	var row := GridContainer.new()
	row.columns = 4
	row.position = Vector2(466, 33)
	row.z_index = 250
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("h_separation", 2)
	row.add_theme_constant_override("v_separation", 2)
	add_child(row)
	var group := ButtonGroup.new()
	for index in range(layout_names.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(36, 32)
		button.text = str(index + 1)
		button.tooltip_text = layout_names[index]
		button.add_theme_font_size_override("font_size", 15)
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(index == selected_index)
		button.pressed.connect(func() -> void: layout_selected.emit(index))
		row.add_child(button)
		layout_buttons.append(button)


func add_action_preview_button() -> void:
	action_preview_button = Button.new()
	action_preview_button.name = "ActionPreviewButton"
	action_preview_button.position = Vector2(24, 30)
	action_preview_button.custom_minimum_size = Vector2(148, 36)
	action_preview_button.z_index = 250
	action_preview_button.add_theme_font_override("font", DETAIL_FONT)
	action_preview_button.add_theme_font_size_override("font_size", 16)
	action_preview_button.tooltip_text = "누를 때마다 적 행동 아이콘 예시를 바꿉니다."
	action_preview_button.pressed.connect(func() -> void: action_preview_pressed.emit())
	add_child(action_preview_button)


func set_action_preview_page(page: int, page_count: int) -> void:
	action_preview_button.text = "행동 예고 · 실제" if page == 0 else "아이콘 테스트 %d/%d" % [page, page_count]


func set_layouts_locked(locked: bool) -> void:
	for button in layout_buttons:
		button.disabled = locked


func _sprite_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2(-0.5, -0.5, 1.0, 1.0)
	if not opaque_bounds.has(texture):
		var image := texture.get_image()
		var bounds := Rect2(-0.5, -0.5, 1.0, 1.0)
		if image != null and not image.is_empty():
			var used := image.get_used_rect()
			if used.has_area():
				var image_size := Vector2(image.get_size())
				bounds = Rect2(Vector2(used.position) / image_size - Vector2.ONE * 0.5, Vector2(used.size) / image_size)
		opaque_bounds[texture] = bounds
	return opaque_bounds[texture]


func sprite_span(character: CharacterData, size_factor: float) -> Vector2:
	if character.sprite == null:
		return Vector2(-55, 55) * size_factor
	var bounds := _sprite_bounds(character.sprite)
	var span := Vector2(bounds.position.x, bounds.end.x)
	if character.sprite_flip_h:
		span = Vector2(-span.y, -span.x)
	return (span * character.sprite_size.x + Vector2.ONE * character.sprite_horizontal_offset) * size_factor


func sprite_vertical_span(character: CharacterData) -> Vector2:
	if character.sprite == null:
		return Vector2(-75.0, 75.0)
	var bounds := _sprite_bounds(character.sprite)
	return Vector2(bounds.position.y, bounds.end.y) * character.sprite_size.y + Vector2.ONE * character.sprite_height_offset


func position_shadow(fighter: Fighter, foot_offset: float, enabled: bool, offset: Vector2, scale_multiplier: Vector2) -> void:
	var anchor := fighter.get_parent()
	var shadow := anchor.get_node_or_null("FootShadow") as Polygon2D
	if not enabled:
		if shadow != null:
			shadow.hide()
		return
	if shadow == null:
		shadow = Polygon2D.new()
		shadow.name = "FootShadow"
		var points := PackedVector2Array()
		for index in range(20):
			points.append(Vector2.from_angle(TAU * index / 20.0))
		shadow.polygon = points
		shadow.color = Color(0.08, 0.07, 0.16, 0.25)
		shadow.z_as_relative = false
		shadow.z_index = 2
		anchor.add_child(shadow)
	var span := sprite_span(fighter.character_data, fighter.base_scale.x)
	shadow.position = Vector2((span.x + span.y) * 0.5, foot_offset) + offset
	shadow.scale = Vector2((span.y - span.x) * 0.28, 4.0) * scale_multiplier
	shadow.show()


func _add_health_bar(fighter: Fighter, joined: bool) -> void:
	var bar := HealthBarScene.instantiate() as WaterHealthBar
	bar.scale = Vector2.ONE * (JOINED_HEALTH_SCALE if joined else HEALTH_BAR_SCALE)
	info_layer.add_child(bar)
	bar.value_label.hide()
	bar.value_label_background.hide()
	_add_health_gauge_track(bar, joined)
	bar.set_health(fighter.current_health, fighter.max_health)
	fighter.set_meta("formation_info", bar)
	fighter.health_changed.connect(func(health: int, maximum: int) -> void:
		bar.set_health(health if maximum > 0 else 0, maximum)
	)
	fighters[bar] = fighter
	fighter.tree_exiting.connect(func() -> void:
		fighters.erase(bar)
		bar.queue_free()
	)
	var badge_backdrop := Panel.new()
	badge_backdrop.name = "AttackBadgeBackdrop"
	badge_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.05, 0.15, 0.96)
	badge_style.border_color = Color(0.75, 0.60, 0.88, 0.95)
	badge_style.set_border_width_all(4)
	badge_style.set_corner_radius_all(58)
	badge_backdrop.add_theme_stylebox_override("panel", badge_style)
	bar.add_child(badge_backdrop)
	var badge := HBoxContainer.new()
	badge.name = "AttackCountdown"
	badge.position = Vector2(-139.0, -62.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_constant_override("separation", 2)
	bar.add_child(badge)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = ActionIcons.ATTACK_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(104.0, 104.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	var turns := Label.new()
	turns.name = "Turns"
	turns.text = "3"
	turns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turns.add_theme_font_override("font", DETAIL_FONT)
	turns.add_theme_font_size_override("font_size", 60)
	turns.add_theme_color_override("font_color", Color(1.0, 0.87, 0.61))
	turns.add_theme_color_override("font_outline_color", Color(0.07, 0.04, 0.15))
	turns.add_theme_constant_override("outline_size", 12)
	badge.add_child(turns)
	var padding := Vector2(8.0, 6.0)
	var total_padding := padding * 2.0 + (Vector2(16.0, 0.0) if joined else Vector2.ZERO)
	var accessory_scale := HEALTH_BAR_SCALE / bar.scale.x
	badge.scale = Vector2.ONE * accessory_scale
	badge_backdrop.scale = badge.scale
	var badge_size := badge.get_combined_minimum_size() + total_padding
	badge_backdrop.size = badge_size
	badge_backdrop.position = badge.position - padding
	if joined:
		var frame_rect := (bar.get_node("Frame") as TextureRect).get_rect()
		var seam := Vector2(frame_rect.position.x + 12.0, bar.full_health_fill.get_rect().get_center().y)
		badge_backdrop.position = seam - Vector2(badge_size.x, badge_size.y * 0.5) * accessory_scale
		badge.position = badge_backdrop.position + padding * accessory_scale
		bar.move_child(badge_backdrop, bar.full_health_fill.get_index())
	badge.resized.connect(func() -> void: badge_backdrop.size = badge.size + total_padding)
	var backdrop_origin := badge_backdrop.position * bar.scale.x
	var info_offset := BAR_OFFSET
	var info_size := INFO_BOUNDS
	if joined:
		info_offset = Vector2(ceilf(-backdrop_origin.x) + 2.0, 54.0)
		info_size = Vector2(info_offset.x + bar.size.x * bar.scale.x, info_offset.y + bar.size.y * bar.scale.y)
	bar.set_meta("info_offset", info_offset)
	bar.set_meta("info_size", info_size)
	var effects := StatusEffectBar.new()
	effects.name = "Effects"
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.position = Vector2(65.0, -136.0) * accessory_scale
	effects.scale = Vector2.ONE * 1.22 * accessory_scale
	bar.add_child(effects)
	_update_effects(effects)
	var connector := Line2D.new()
	connector.name = "AnchorLine"
	connector.width = 4.0
	connector.default_color = Color(0.9, 0.82, 1.0, 0.65)
	connector.z_index = -1
	bar.add_child(connector)


func _add_health_gauge_track(bar: WaterHealthBar, joined: bool) -> void:
	var fill := bar.full_health_fill
	var track := Panel.new()
	track.name = "HealthTrack"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.position = fill.position
	track.size = fill.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#171d2b")
	style.set_corner_radius_all(8)
	track.add_theme_stylebox_override("panel", style)
	bar.add_child(track)
	bar.move_child(track, fill.get_index())

	var divisions := Control.new()
	divisions.name = "HealthDivisions"
	divisions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divisions.position = track.position
	divisions.size = track.size
	bar.add_child(divisions)
	bar.move_child(divisions, bar.durability_fill.get_index() + 1)
	for quarter in range(1, 4):
		var marker := ColorRect.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.color = Color("#45546a") if joined else Color("#526073")
		marker.size = Vector2(7.0 if joined else 3.0, track.size.y - 2.0)
		marker.position = Vector2(track.size.x * quarter / 4.0 - marker.size.x * 0.5, 1.0)
		divisions.add_child(marker)


func set_action_preview(fighter: Fighter, kind: int, turns: int, demo := false) -> void:
	var bar: WaterHealthBar = fighter.get_meta("formation_info")
	var icon := bar.get_node("AttackCountdown/Icon") as TextureRect
	var counter := bar.get_node("AttackCountdown/Turns") as Label
	if not bar.has_meta("action_kind") or bar.get_meta("action_kind") != kind:
		icon.texture = ActionIcons.texture_for(kind)
	bar.set_meta("action_kind", kind)
	bar.set_meta("action_demo", demo)
	counter.text = str(turns) if turns >= 0 else "–"


func set_effect_state(vulnerable: int, reduced_attack: float) -> void:
	if weakness_turns == vulnerable and is_equal_approx(attack_reduction, reduced_attack):
		return
	attack_reduction = reduced_attack
	weakness_turns = vulnerable
	for bar in fighters:
		_update_effects(bar.get_node("Effects") as StatusEffectBar)


func _update_effects(effects: StatusEffectBar) -> void:
	if weakness_turns > 0:
		effects.set_effect(WEAKNESS_EFFECT, weakness_turns)
	else:
		effects.remove_effect(WEAKNESS_EFFECT.effect_id)
	if attack_reduction > 0.0:
		effects.set_effect(reduction_effect, 0)
	else:
		effects.remove_effect(reduction_effect.effect_id)


func position_info(fighter: Fighter, slot_position: Vector2, offset: Vector2) -> void:
	var bar: WaterHealthBar = fighter.get_meta("formation_info")
	var character := fighter.character_data
	var size_factor := fighter.base_scale.x
	var span := sprite_span(character, size_factor)
	var vertical := sprite_vertical_span(character) * size_factor
	var head := slot_position + Vector2((span.x + span.y) * 0.5, vertical.x)
	bar.set_meta("head_anchor", head)
	bar.set_meta("sprite_rect", Rect2(slot_position + Vector2(span.x, vertical.x), Vector2(span.y - span.x, vertical.y - vertical.x)))
	if fighter == marked_enemy:
		_position_target_marker(fighter)
	var info_offset: Vector2 = bar.get_meta("info_offset")
	var info_size: Vector2 = bar.get_meta("info_size")
	var center_offset := info_offset.x + bar.size.x * bar.scale.x * 0.5
	bar.set_meta("preferred_origin", head - Vector2(center_offset, info_size.y + 5.0 - offset.y))


func set_attack_target(fighter: Fighter, manual: bool) -> void:
	marked_enemy = fighter
	target_marker.color = Color("#ffda79") if manual else Color("#81eaff")
	target_marker.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(0, -11), Vector2(10, 0), Vector2(0, 6)]) if manual else PackedVector2Array([Vector2(-9, -7), Vector2(9, -7), Vector2(0, 4)])
	_position_target_marker(fighter)


func _position_target_marker(fighter: Fighter) -> void:
	target_marker.hide()
	if not is_instance_valid(fighter):
		return
	var bar: WaterHealthBar = fighter.get_meta("formation_info")
	if not bar.has_meta("sprite_rect"):
		return
	var bounds: Rect2 = bar.get_meta("sprite_rect")
	target_marker.position = Vector2(bounds.get_center().x, bounds.end.y + 3.0)
	target_marker.show()


func reflow_info() -> void:
	var bars: Array[WaterHealthBar] = []
	for bar in fighters:
		if bar.visible and bar.has_meta("preferred_origin"):
			bars.append(bar)
	bars.sort_custom(func(a: WaterHealthBar, b: WaterHealthBar) -> bool:
		return Vector2(a.get_meta("preferred_origin")).y < Vector2(b.get_meta("preferred_origin")).y
	)
	var occupied: Array[Rect2] = []
	for bar in bars:
		var preferred: Vector2 = bar.get_meta("preferred_origin")
		var head: Vector2 = bar.get_meta("head_anchor")
		var info_size: Vector2 = bar.get_meta("info_size")
		var best := Rect2()
		var best_cost := INF
		var bottom := 428.0 - info_size.y
		var heights := PackedFloat32Array([clampf(preferred.y, 91.0, bottom)])
		for y in range(91, floori(bottom) + 1, 4):
			heights.append(y)
		for y in heights:
			var origin := Vector2(preferred.x, y)
			var area := Rect2(origin, info_size)
			var cost := origin.distance_squared_to(preferred) + maxf(0.0, area.end.y - head.y) * 650.0
			for used in occupied:
				if area.grow(2.0).intersects(used):
					cost += 1000000.0
			for other in bars:
				if other != bar:
					var sprite_overlap := area.intersection(other.get_meta("sprite_rect"))
					cost += sprite_overlap.get_area() * 4.0
			if cost < best_cost:
				best_cost = cost
				best = area
		occupied.append(best)
		bar.position = best.position + Vector2(bar.get_meta("info_offset"))
		var connector := bar.get_node("AnchorLine") as Line2D
		var tail := Vector2(head.x, best.end.y - 3.0)
		connector.visible = head.y - tail.y > 26.0
		connector.points = PackedVector2Array([(tail - bar.position) / bar.scale.x, (head - bar.position) / bar.scale.x])


func _create_detail_panel() -> void:
	detail_panel = EnemyDetails.new()
	add_child(detail_panel)
	detail_panel.close_requested.connect(_close_details)
	detail_panel.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pointer := -2
	var pressed := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		pointer = event.index
		pressed = event.pressed and not event.canceled
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -1
		pressed = event.pressed
		point = event.position
	if pointer == -2:
		return
	if not pressed and captured_pointer == pointer:
		captured_pointer = -2
		get_viewport().set_input_as_handled()
	elif captured_pointer != -2:
		get_viewport().set_input_as_handled()
	elif pressed and captured_pointer == -2:
		var local_point := get_global_transform_with_canvas().affine_inverse() * point
		if detail_panel.visible and detail_panel.get_rect().has_point(local_point):
			return
		var top_z := -4096
		var clicked_enemy: Fighter
		for bar in fighters:
			if not bar.visible or not bar.has_meta("sprite_rect"):
				continue
			var fighter := fighters[bar]
			var sprite_rect: Rect2 = bar.get_meta("sprite_rect")
			var fighter_z: int = fighter.get_parent().z_index
			if sprite_rect.has_point(local_point) and fighter_z >= top_z:
				top_z = fighter_z
				clicked_enemy = fighter
		if is_instance_valid(clicked_enemy):
			captured_pointer = pointer
			enemy_clicked.emit(clicked_enemy)
			if clicked_enemy != selected_enemy:
				selected_enemy = clicked_enemy
				detail_panel.reset_scroll()
				_refresh_details()
			get_viewport().set_input_as_handled()
		elif detail_panel.visible:
			captured_pointer = pointer
			_close_details()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_instance_valid(selected_enemy):
		_refresh_details()


func _refresh_details() -> void:
	var bar: WaterHealthBar = selected_enemy.get_meta("formation_info")
	var kind: int = bar.get_meta("action_kind", -1)
	var demo: bool = bar.get_meta("action_demo", false)
	var counter := bar.get_node("AttackCountdown/Turns") as Label
	var icon := bar.get_node("AttackCountdown/Icon") as TextureRect
	var damage := roundi(selected_enemy.attack_power * (1.0 - attack_reduction))
	detail_panel.present(selected_enemy, kind, counter.text, icon.texture, damage, demo)
	var effect_count := 0
	if weakness_turns > 0:
		var extra_damage := roundi((WEAKNESS_EFFECT.incoming_damage_multiplier - 1.0) * 100.0)
		detail_panel.set_effect(effect_count, WEAKNESS_EFFECT.icon, "쇠약", "%d턴" % weakness_turns,
			"받는 피해가 %d%% 증가합니다." % extra_damage)
		effect_count += 1
	if attack_reduction > 0.0:
		detail_panel.set_effect(effect_count, reduction_effect.icon, "공격력 감소", "%d턴" % real_attack_turns,
			"가하는 피해가 %d%% 감소합니다." % roundi(attack_reduction * 100.0))
		effect_count += 1
	detail_panel.trim_effects(effect_count)
	var viewport_size := get_viewport_rect().size
	var panel_width := maxf(EnemyDetails.WIDTH, detail_panel.size.x)
	detail_panel.position = Vector2((viewport_size.x - panel_width) * 0.5, 440.0)
	detail_panel.show()


func _close_details() -> void:
	selected_enemy = null
	detail_panel.hide()
	detail_panel.reset_scroll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(detail_panel):
		captured_pointer = -2
		_close_details()
