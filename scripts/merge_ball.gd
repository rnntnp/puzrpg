class_name MergeBall
extends RigidBody2D

signal merge_requested(first: MergeBall, second: MergeBall)
signal first_contact(ball: MergeBall)

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")
@onready var sprite: Sprite2D = $Sprite2D
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
var horizontal_bounds_enabled := false
var horizontal_bound_left := 0.0
var horizontal_bound_right := 720.0
var floor_bound_bottom := 850.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(level: int, physics_speed: float = 1.0) -> void:
	merge_level = clampi(level, 0, BallCatalogClass.get_max_level_index())
	ball_data = BallCatalogClass.get_ball(merge_level)
	collision_shape.shape = ball_data.collision_shape
	sprite.show_behind_parent = true
	sprite.texture = ball_data.sprite
	sprite.modulate = ball_data.sprite_modulate
	var texture_size := sprite.texture.get_size() if sprite.texture != null else Vector2.ONE
	var diameter: float = ball_data.get_radius() * 2.0
	sprite.scale = Vector2(diameter / texture_size.x, diameter / texture_size.y)
	glow_aura.setup(ball_data.get_radius(), ball_data.glow_color, ball_data.glow_strength)
	mass = maxf(1.0, ball_data.get_radius() / 20.0)
	# 자유 낙하 시간은 중력의 제곱근에 반비례하므로 배속의 제곱을 적용한다.
	gravity_scale = physics_speed * physics_speed
	queue_redraw()


func set_play_area_bounds(left: float, right: float, bottom: float) -> void:
	horizontal_bound_left = left
	horizontal_bound_right = right
	floor_bound_bottom = bottom
	horizontal_bounds_enabled = right > left


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
	var maximum_y := floor_bound_bottom - radius
	if transform.origin.y > maximum_y:
		transform.origin.y = maximum_y
		velocity.y = minf(0.0, velocity.y)
	state.transform = transform
	state.linear_velocity = velocity

func lock_for_merge() -> void:
	merge_locked = true
	collision_layer = 0
	collision_mask = 0
	set_deferred("freeze", true)


func get_radius() -> float:
	return ball_data.get_radius() if ball_data != null else 0.0


func get_merge_score() -> int:
	return ball_data.merge_score if ball_data != null else 0


func set_ingestion_marked(marked: bool) -> void:
	ingestion_marked = marked
	queue_redraw()


func set_ice_targeted(targeted: bool) -> void:
	ice_targeted = targeted
	queue_redraw()


func freeze_in_ice(durability: int) -> void:
	if merge_locked or is_ice_frozen:
		return
	is_ice_frozen = true
	ice_durability = maxi(1, durability)
	ice_durability_label.text = str(ice_durability)
	ice_durability_label.visible = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	queue_redraw()


func damage_ice(amount: int) -> void:
	if not is_ice_frozen or amount <= 0:
		return
	ice_durability = maxi(0, ice_durability - amount)
	ice_durability_label.text = str(ice_durability)
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
	ice_durability_label.visible = false
	freeze = false
	queue_redraw()
	if play_effect:
		modulate = Color("#bdefff")
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	print("[ICE BREAK] level=%d" % (merge_level + 1))

func _draw() -> void:
	var radius := get_radius()
	if ball_data == null or ball_data.show_placeholder_outline:
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 40, Color("#162033"), 5.0, true)
	if ingestion_marked:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 40, Color("#c477ff"), 6.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -radius - 18.0),
			Vector2(-9.0, -radius - 33.0),
			Vector2(9.0, -radius - 33.0),
		]), Color("#e0a6ff"))
	if ice_targeted:
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 40, Color("#d7f7ff"), 8.0, true)
	if is_ice_frozen:
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.36, 0.82, 1.0, 0.38))
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40, Color("#9eeaff"), 6.0, true)

func _on_body_entered(body: Node) -> void:
	# 옆 벽 접촉은 다음 공 활성화 조건이 아니다.
	var is_drop_landing_contact := body is MergeBall or body.name == &"Floor"
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
