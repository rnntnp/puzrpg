class_name MergeBall
extends RigidBody2D

signal merge_requested(first: MergeBall, second: MergeBall)
signal first_contact(ball: MergeBall)

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")

@onready var sprite: Sprite2D = $Sprite2D
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
	mass = maxf(1.0, ball_data.get_radius() / 20.0)
	# 자유 낙하 시간은 중력의 제곱근에 반비례하므로 배속의 제곱을 적용한다.
	gravity_scale = physics_speed * physics_speed
	queue_redraw()

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
	if not _has_contacted:
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
