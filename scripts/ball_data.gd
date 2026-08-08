class_name BallData
extends Resource

enum BallShape {
	CIRCLE,
}

@export_category("기본 정보")
@export_range(1, 99, 1) var level: int = 1
@export var shape: BallShape = BallShape.CIRCLE

@export_category("표시")
@export var sprite: Texture2D
@export var sprite_modulate: Color = Color.WHITE

@export_category("물리")
@export var collision_shape: Shape2D

@export_category("머지")
@export_range(0, 99999, 1) var merge_score: int = 10


func get_radius() -> float:
	if collision_shape is CircleShape2D:
		return (collision_shape as CircleShape2D).radius
	return 0.0
