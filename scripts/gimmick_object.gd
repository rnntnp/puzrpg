class_name GimmickObject
extends RigidBody2D

enum ObjectKind { ROCK, LIFE_BUBBLE, BUMPER }

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var value_label: Label = $ValueLabel

var object_kind := ObjectKind.ROCK
var durability := 0
var maximum_durability := 0
var shield := 0
var maximum_shield := 0
var object_size := Vector2(90.0, 120.0)
var object_radius := 42.0


func configure_rock(size: Vector2, hit_points: int, falling: bool) -> void:
	object_kind = ObjectKind.ROCK
	object_size = size
	durability = maxi(1, hit_points)
	maximum_durability = durability
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape
	mass = 14.0
	freeze = not falling
	_update_label()
	queue_redraw()


func configure_life_bubble(radius: float, hit_points: int, max_shield: int) -> void:
	object_kind = ObjectKind.LIFE_BUBBLE
	object_radius = radius
	durability = maxi(1, hit_points)
	maximum_durability = durability
	maximum_shield = maxi(0, max_shield)
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	mass = 3.0
	freeze = false
	_update_label()
	queue_redraw()


func configure_bumper(radius: float) -> void:
	object_kind = ObjectKind.BUMPER
	object_radius = radius
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	freeze = true
	_update_label()
	queue_redraw()


func take_obstacle_hit() -> bool:
	durability = maxi(0, durability - 1)
	_update_label()
	queue_redraw()
	return durability <= 0


func grant_shield() -> void:
	shield = mini(maximum_shield, shield + 1)
	_update_label()
	queue_redraw()


func take_life_hit() -> bool:
	if shield > 0:
		shield -= 1
	else:
		durability = maxi(0, durability - 1)
	_update_label()
	queue_redraw()
	return durability <= 0


func _update_label() -> void:
	if value_label == null:
		return
	value_label.visible = object_kind != ObjectKind.BUMPER
	if object_kind == ObjectKind.LIFE_BUBBLE:
		value_label.text = "♥ %d%s" % [durability, "  ◆" if shield > 0 else ""]
	else:
		value_label.text = str(durability)


func _draw() -> void:
	if object_kind == ObjectKind.LIFE_BUBBLE:
		draw_circle(Vector2.ZERO, object_radius, Color(0.25, 0.9, 0.95, 0.72))
		draw_arc(Vector2.ZERO, object_radius, 0.0, TAU, 48, Color("#d7ffff"), 5.0, true)
		if shield > 0:
			draw_arc(Vector2.ZERO, object_radius + 10.0, 0.0, TAU, 48, Color("#ffe66d"), 6.0, true)
		return
	if object_kind == ObjectKind.BUMPER:
		draw_circle(Vector2.ZERO, object_radius, Color("#ff9f1c"))
		draw_circle(Vector2.ZERO, object_radius * 0.68, Color("#ffe66d"))
		draw_arc(Vector2.ZERO, object_radius, 0.0, TAU, 48, Color.WHITE, 5.0, true)
		return
	var rect := Rect2(-object_size * 0.5, object_size)
	draw_rect(rect, Color("#5c6575"), true)
	draw_rect(rect, Color("#b9c1cf"), false, 5.0)
	var crack_alpha := 0.25 + 0.65 * (1.0 - float(durability) / float(maximum_durability))
	draw_line(Vector2(-8, -object_size.y * 0.45), Vector2(5, -5), Color(0.1, 0.12, 0.16, crack_alpha), 4.0)
	draw_line(Vector2(5, -5), Vector2(-14, object_size.y * 0.34), Color(0.1, 0.12, 0.16, crack_alpha), 4.0)
