class_name MergeBall
extends RigidBody2D

signal merge_requested(first: MergeBall, second: MergeBall)
signal first_contact(ball: MergeBall)

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
const LEGACY_VISUAL_SCENE := preload("res://scenes/balls/visuals/ball_visual_base.tscn")
const VISUAL_DESIGN_SIZE := 418.0
const FLOOR_RECOVERY_MARGIN := 4.0
@onready var visual_container: Node2D = $VisualContainer
@onready var glow_aura = $GlowAura
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ice_durability_label: Label = $IceDurabilityLabel
var merge_level := 0
var merge_locked := false
var ball_data: Resource
var _has_contacted := false
var ingestion_marked := false
var is_ice_frozen := false
var ice_durability := 0
var ice_targeted := false
var split_targeted := false
var split_target_color := Color("#ffd166")
var horizontal_bounds_enabled := false
var horizontal_bound_left := 0.0
var horizontal_bound_right := 720.0
var floor_bound_bottom := 850.0
var base_mass := 1.0
var is_enlarged := false
var is_heavy := false
var hazard_turns := 0
var sealed_visual := false
var portal_cooldown_until_msec := 0
var vertical_floor_bound_enabled := true
var is_submerged := false
var is_merge_cursed := false
var curse_preview := false
var rewind_turns := 0
var bumper_cooldown_until_msec := 0
var danger_marked := false
var _hitbox_radius := 0.0
var sleep_assist_enabled := false
var sleep_assist_settle_time := 1.5
var sleep_assist_max_displacement := 1.5
var _sleep_assist_sample_position := Vector2.ZERO
var _sleep_assist_sample_time := 0.0
var _sleep_assist_sample_active := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(level: int, physics_speed: float = 1.0) -> void:
	merge_level = clampi(level, 0, BallCatalogClass.get_max_level_index())
	ball_data = BallCatalogClass.get_ball(merge_level)
	var diameter: float = ball_data.get_radius() * 2.0
	var visual := _setup_visual(diameter)
	_setup_collision_shape(visual)
	glow_aura.setup(
		ball_data.get_radius() * ball_data.glow_radius_scale,
		ball_data.glow_color,
		ball_data.glow_strength
	)
	base_mass = maxf(1.0, ball_data.get_radius() / 20.0)
	mass = base_mass
	# 자유 낙하 시간은 중력의 제곱근에 반비례하므로 배속의 제곱을 적용한다.
	gravity_scale = physics_speed * physics_speed
	queue_redraw()


func _setup_visual(diameter: float) -> Node2D:
	for child in visual_container.get_children():
		child.queue_free()
	var scene: PackedScene = ball_data.visual_scene if ball_data.visual_scene != null else LEGACY_VISUAL_SCENE
	var visual := scene.instantiate() as Node2D
	visual_container.add_child(visual)
	visual_container.scale = Vector2.ONE * (diameter / VISUAL_DESIGN_SIZE)
	if ball_data.visual_scene != null:
		return visual
	# 아직 전용 비주얼 씬이 없는 10·11단계의 호환 표시.
	var axolotl := visual.get_node_or_null("Axolotl") as Sprite2D
	var shell_base := visual.get_node_or_null("ShellBase") as Sprite2D
	var shell_shadow := visual.get_node_or_null("ShellShadow") as Sprite2D
	if axolotl != null:
		axolotl.texture = ball_data.sprite
		axolotl.modulate = ball_data.sprite_modulate
		if ball_data.sprite != null:
			var texture_size: Vector2 = ball_data.sprite.get_size()
			axolotl.scale = Vector2(VISUAL_DESIGN_SIZE / texture_size.x, VISUAL_DESIGN_SIZE / texture_size.y)
	if shell_base != null:
		shell_base.modulate = ball_data.glow_color
	if shell_shadow != null:
		shell_shadow.modulate = ball_data.glow_color.darkened(0.62)
	return visual


func set_play_area_bounds(left: float, right: float, bottom: float) -> void:
	horizontal_bound_left = left
	horizontal_bound_right = right
	floor_bound_bottom = bottom
	horizontal_bounds_enabled = right > left


func configure_sleep_assist(enabled: bool, settle_time: float, max_displacement: float) -> void:
	sleep_assist_enabled = enabled
	sleep_assist_settle_time = maxf(0.0, settle_time)
	sleep_assist_max_displacement = maxf(0.0, max_displacement)
	_reset_sleep_assist_sample()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not horizontal_bounds_enabled or merge_locked:
		return
	var radius := get_radius()
	var transform := state.transform
	var velocity := state.linear_velocity
	var minimum_x := horizontal_bound_left + radius
	var maximum_x := horizontal_bound_right - radius
	# 큰 충격으로 한 물리 프레임 안에 벽을 통과해도 공 전체를 박스 내부에 유지한다.
	if transform.origin.x < minimum_x:
		transform.origin.x = minimum_x
		velocity.x = maxf(0.0, velocity.x)
	elif transform.origin.x > maximum_x:
		transform.origin.x = maximum_x
		velocity.x = minf(0.0, velocity.x)
	# 정상적인 벽 접촉은 StaticBody2D에 맡기고, 실제 관통 때만 복구한다.
	if vertical_floor_bound_enabled:
		var maximum_y := floor_bound_bottom - radius + FLOOR_RECOVERY_MARGIN
		if transform.origin.y > maximum_y:
			transform.origin.y = maximum_y
			velocity.y = minf(0.0, velocity.y)
	state.transform = transform
	state.linear_velocity = velocity
	_update_sleep_assist(state)


func _update_sleep_assist(state: PhysicsDirectBodyState2D) -> void:
	if not sleep_assist_enabled or is_ice_frozen or freeze:
		_reset_sleep_assist_sample()
		return
	if state.get_contact_count() <= 0:
		_reset_sleep_assist_sample()
		return
	var current_position := state.transform.origin
	if not _sleep_assist_sample_active:
		_sleep_assist_sample_position = current_position
		_sleep_assist_sample_time = 0.0
		_sleep_assist_sample_active = true
		return
	if current_position.distance_to(_sleep_assist_sample_position) > sleep_assist_max_displacement:
		_sleep_assist_sample_position = current_position
		_sleep_assist_sample_time = 0.0
		return
	_sleep_assist_sample_time += state.step
	if _sleep_assist_sample_time < sleep_assist_settle_time:
		return
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0
	state.sleeping = true
	_reset_sleep_assist_sample()


func _reset_sleep_assist_sample() -> void:
	_sleep_assist_sample_position = Vector2.ZERO
	_sleep_assist_sample_time = 0.0
	_sleep_assist_sample_active = false

func lock_for_merge() -> void:
	merge_locked = true
	collision_layer = 0
	collision_mask = 0
	set_deferred("freeze", true)


func get_radius() -> float:
	return _hitbox_radius * absf(scale.x)


func _setup_collision_shape(visual: Node2D) -> void:
	for child in get_children():
		if child is CollisionShape2D and child != collision_shape and child.has_meta(&"visual_hitbox"):
			child.queue_free()
	var authoring_root := visual.get_node_or_null("HitboxAuthoring") as StaticBody2D
	if authoring_root != null and _copy_authored_hitboxes(authoring_root):
		return
	_setup_fallback_collision_shape()


func _copy_authored_hitboxes(authoring_root: StaticBody2D) -> bool:
	var source_shapes: Array[CollisionShape2D] = []
	for child in authoring_root.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled and (child as CollisionShape2D).shape != null:
			source_shapes.append(child as CollisionShape2D)
	if source_shapes.is_empty():
		return false
	var design_scale := visual_container.scale.x
	_hitbox_radius = 0.0
	for index in source_shapes.size():
		var source := source_shapes[index]
		var target := collision_shape if index == 0 else CollisionShape2D.new()
		target.shape = source.shape.duplicate(true)
		var runtime_transform := authoring_root.transform * source.transform
		runtime_transform.origin *= design_scale
		runtime_transform.x *= design_scale
		runtime_transform.y *= design_scale
		target.transform = runtime_transform
		if index > 0:
			target.set_meta(&"visual_hitbox", true)
			add_child(target)
		_hitbox_radius = maxf(_hitbox_radius, _get_shape_extent(target))
	authoring_root.process_mode = Node.PROCESS_MODE_DISABLED
	authoring_root.visible = false
	return true


func _get_shape_extent(shape_node: CollisionShape2D) -> float:
	var extent := shape_node.position.length()
	var maximum_scale := maxf(absf(shape_node.scale.x), absf(shape_node.scale.y))
	if shape_node.shape is CircleShape2D:
		return extent + (shape_node.shape as CircleShape2D).radius * maximum_scale
	if shape_node.shape is ConvexPolygonShape2D:
		for point in (shape_node.shape as ConvexPolygonShape2D).points:
			extent = maxf(extent, (shape_node.transform * point).length())
	return extent


func _setup_fallback_collision_shape() -> void:
	_hitbox_radius = ball_data.get_hitbox_radius()
	var runtime_collision_shape: Shape2D = ball_data.collision_shape.duplicate()
	if runtime_collision_shape is CircleShape2D:
		(runtime_collision_shape as CircleShape2D).radius = _hitbox_radius
	collision_shape.shape = runtime_collision_shape


func set_enlarged(enabled: bool, multiplier := 1.5, duration := 0.25) -> void:
	is_enlarged = enabled
	var target_scale := Vector2.ONE * (multiplier if enabled else 1.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, maxf(0.01, duration)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func set_heavy(enabled: bool, multiplier := 4.0) -> void:
	is_heavy = enabled
	mass = base_mass * (multiplier if enabled else 1.0)
	queue_redraw()


func set_hazard_turns(value: int) -> void:
	hazard_turns = maxi(0, value)
	queue_redraw()


func set_sealed_visual(enabled: bool) -> void:
	sealed_visual = enabled
	queue_redraw()


func set_submerged(enabled: bool) -> void:
	is_submerged = enabled
	queue_redraw()


func set_merge_curse(enabled: bool, preview := false) -> void:
	is_merge_cursed = enabled
	curse_preview = preview
	queue_redraw()


func set_rewind_turns(turns: int) -> void:
	rewind_turns = maxi(0, turns)
	queue_redraw()


func get_merge_score() -> int:
	return ball_data.merge_score if ball_data != null else 0


func has_landed() -> bool:
	return _has_contacted


func set_ingestion_marked(marked: bool) -> void:
	ingestion_marked = marked
	queue_redraw()


func set_ice_targeted(targeted: bool) -> void:
	ice_targeted = targeted
	if visual_container.get_child_count() > 0:
		var visual := visual_container.get_child(0)
		if visual != null and visual.has_method("set_ice_targeted_visual"):
			visual.call("set_ice_targeted_visual", targeted)
	queue_redraw()

func set_danger_marked(marked: bool) -> void:
	danger_marked = marked
	queue_redraw()


func set_split_targeted(targeted: bool, marker_color: Color = Color("#ffd166")) -> void:
	split_targeted = targeted
	if targeted:
		split_target_color = marker_color
	queue_redraw()


func freeze_in_ice(durability: int) -> void:
	if merge_locked:
		return
	is_ice_frozen = true
	ice_durability = maxi(1, durability)
	_set_frozen_visual(true)
	_update_ice_durability_visual()
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	queue_redraw()


func damage_ice(amount: int) -> void:
	if not is_ice_frozen or amount <= 0:
		return
	ice_durability = maxi(0, ice_durability - amount)
	_update_ice_durability_visual()
	print("[ICE DAMAGE] level=%d | remaining=%d" % [merge_level + 1, ice_durability])
	if ice_durability <= 0:
		break_ice()
	else:
		var original_rotation := rotation
		var tween := create_tween()
		tween.tween_property(self, "rotation", original_rotation + 0.08, 0.04)
		tween.tween_property(self, "rotation", original_rotation - 0.08, 0.08)
		tween.tween_property(self, "rotation", original_rotation, 0.04)
	queue_redraw()


func break_ice(play_effect := true) -> void:
	if not is_ice_frozen:
		return
	is_ice_frozen = false
	ice_durability = 0
	_set_frozen_visual(false)
	ice_durability_label.visible = false
	freeze = false
	queue_redraw()
	if play_effect:
		modulate = Color("#bdefff")
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	print("[ICE BREAK] level=%d" % (merge_level + 1))


func _set_frozen_visual(enabled: bool) -> void:
	if visual_container.get_child_count() == 0:
		return
	var visual := visual_container.get_child(0)
	if visual != null and visual.has_method("set_frozen_visual"):
		visual.call("set_frozen_visual", enabled)


func _update_ice_durability_visual() -> void:
	ice_durability_label.visible = false

func _draw() -> void:
	var radius: float = ball_data.get_radius() if ball_data != null else 0.0
	if ball_data == null or ball_data.show_placeholder_outline:
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 40, Color("#162033"), 5.0, true)
	if ingestion_marked:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 40, Color("#c477ff"), 6.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -radius - 18.0),
			Vector2(-9.0, -radius - 33.0),
			Vector2(9.0, -radius - 33.0),
		]), Color("#e0a6ff"))
	if danger_marked:
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 40, Color("#ff4d5f"), 7.0, true)
	if split_targeted:
		var split_marker_radius := get_radius()
		draw_arc(Vector2.ZERO, split_marker_radius + 4.0, 0.0, TAU, 40, split_target_color, 4.0, true)
	if is_enlarged:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 40, Color("#ff9f43"), 6.0, true)
	if is_heavy:
		draw_circle(Vector2(0.0, -radius * 0.1), 11.0, Color("#3c4554"))
		draw_string(ThemeDB.fallback_font, Vector2(-8.0, 7.0), "▼", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 18, Color.WHITE)
	if hazard_turns > 0:
		draw_arc(Vector2.ZERO, radius + 11.0, 0.0, TAU, 40, Color("#ff4d6d"), 6.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-8.0, -radius - 13.0), str(hazard_turns), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 18, Color.WHITE)
	if sealed_visual:
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 40, Color("#b197fc"), 7.0, true)
		draw_line(Vector2(-radius * 0.55, 0), Vector2(radius * 0.55, 0), Color("#e5dbff"), 5.0, true)
	if is_submerged:
		draw_circle(Vector2.ZERO, radius + 3.0, Color(0.25, 0.72, 1.0, 0.18))
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 40, Color(0.45, 0.85, 1.0, 0.8), 3.0, true)
	if is_merge_cursed or curse_preview:
		var curse_color := Color("#c77dff") if is_merge_cursed else Color(0.78, 0.49, 1.0, 0.55)
		draw_arc(Vector2.ZERO, radius + 11.0, 0.0, TAU, 40, curse_color, 6.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-9.0, -radius - 14.0), "☠", HORIZONTAL_ALIGNMENT_CENTER, 18.0, 18, Color.WHITE)
	if rewind_turns > 0:
		draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.35, PI * 1.35, 40, Color("#72ddf7"), 5.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-8.0, -radius - 13.0), str(rewind_turns), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 18, Color.WHITE)

func _on_body_entered(body: Node) -> void:
	# 옆 벽 접촉은 다음 공 활성화 조건이 아니다.
	var is_drop_landing_contact := body is MergeBall or body.name == &"Floor" or body.is_in_group(&"drop_landing_surface")
	if not _has_contacted and is_drop_landing_contact:
		_has_contacted = true
		first_contact.emit(self)
	_try_request_merge(body)


func _try_request_merge(body: Node) -> bool:
	if merge_locked or is_ice_frozen or not body is MergeBall:
		return false
	var other := body as MergeBall
	if other.merge_locked or other.is_ice_frozen:
		return false
	if other.merge_level != merge_level:
		return false
	merge_requested.emit(self, other)
	return true
