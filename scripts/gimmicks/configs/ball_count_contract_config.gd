class_name BallCountContractConfig
extends Resource

## 0=one required zone, 1=two required zones, 2=all three zones.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [3, 4, 5]
@export var success_bonus_damage: Array[int] = [18, 22, 30]
@export var failure_attack_damage: Array[int] = [10, 14, 18]
@export_range(1, 6, 1) var teach_required_addition := 2
## 0=LEFT, 1=CENTER, 2=RIGHT.
@export var teach_zone_pattern: Array[int] = [0, 2, 1]
@export var twist_zone_pairs: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 2),
	Vector2i(0, 2),
]
@export var twist_additions := Vector2i(2, 1)
## Components are LEFT, CENTER, RIGHT additions.
@export var boss_addition_patterns: Array[Vector3i] = [
	Vector3i(2, 1, 1),
	Vector3i(1, 2, 1),
	Vector3i(1, 1, 2),
]
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65
@export_range(0.05, 1.0, 0.05) var live_refresh_interval := 0.15
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5

