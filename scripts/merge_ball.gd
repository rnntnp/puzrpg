class_name MergeBall
extends RigidBody2D

signal merge_requested(first: MergeBall, second: MergeBall)

const COLORS := [
	Color("#55b8ff"), Color("#67dc83"), Color("#ffe066"),
	Color("#ff9f43"), Color("#ff6577"), Color("#b56cff"),
	Color("#57d6c7"), Color("#f28bd4"), Color("#eeeeee"),
	Color("#ff8a3d"), Color("#ffd700")
]
const RADII := [22.0, 28.0, 35.0, 43.0, 52.0, 62.0, 73.0, 84.0, 96.0, 108.0, 122.0]

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var merge_level := 0
var merge_locked := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(level: int) -> void:
	merge_level = clampi(level, 0, COLORS.size() - 1)
	var circle := CircleShape2D.new()
	circle.radius = RADII[merge_level]
	collision_shape.shape = circle
	mass = maxf(1.0, RADII[merge_level] / 20.0)
	queue_redraw()

func lock_for_merge() -> void:
	merge_locked = true
	collision_layer = 0
	collision_mask = 0
	set_deferred("freeze", true)

func get_radius() -> float:
	return RADII[merge_level]

func _draw() -> void:
	var radius: float = RADII[merge_level]
	draw_circle(Vector2.ZERO, radius, COLORS[merge_level])
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 40, Color("#162033"), 5.0, true)

func _on_body_entered(body: Node) -> void:
	if merge_locked or not body is MergeBall:
		return
	var other := body as MergeBall
	if not other.merge_locked and other.merge_level == merge_level and get_instance_id() < other.get_instance_id():
		merge_requested.emit(self, other)
