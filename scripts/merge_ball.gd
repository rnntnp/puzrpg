class_name MergeBall
extends RigidBody2D

signal merge_requested(first: MergeBall, second: MergeBall)

const BallCatalogClass = preload("res://scripts/ball_catalog.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var merge_level := 0
var merge_locked := false
var ball_data: Resource

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(level: int, physics_speed: float = 1.0) -> void:
	merge_level = clampi(level, 0, BallCatalogClass.get_max_level_index())
	ball_data = BallCatalogClass.get_ball(merge_level)
	collision_shape.shape = ball_data.collision_shape
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

func _draw() -> void:
	var radius := get_radius()
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 40, Color("#162033"), 5.0, true)

func _on_body_entered(body: Node) -> void:
	if merge_locked or not body is MergeBall:
		return
	var other := body as MergeBall
	if not other.merge_locked and other.merge_level == merge_level and get_instance_id() < other.get_instance_id():
		merge_requested.emit(self, other)
