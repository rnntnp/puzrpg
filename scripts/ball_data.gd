class_name BallData
extends Resource

enum BallShape {
	CIRCLE,
	HEART,
}

@export_category("기본 정보")
@export_range(1, 99, 1) var level: int = 1
@export var shape: BallShape = BallShape.CIRCLE

@export_category("표시")
@export var sprite: Texture2D
@export var visual_scene: PackedScene
@export var sprite_modulate: Color = Color.WHITE
@export var show_placeholder_outline: bool = true
@export var glow_color: Color = Color(0.55, 0.8, 1.0, 1.0)
@export_range(0.0, 1.0, 0.05) var glow_strength: float = 0.4
@export_range(0.5, 1.5, 0.05) var glow_radius_scale: float = 1.0

@export_category("물리")
@export var collision_shape: Shape2D
@export_range(0.5, 1.2, 0.01) var hitbox_scale: float = 0.9

@export_category("머지")
@export_range(0, 99999, 1) var merge_score: int = 10


func get_radius() -> float:
	if collision_shape is CircleShape2D:
		return (collision_shape as CircleShape2D).radius
	return 0.0


func get_hitbox_radius() -> float:
	return get_radius() * hitbox_scale
