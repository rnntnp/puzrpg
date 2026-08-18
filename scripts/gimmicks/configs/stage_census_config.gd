class_name StageCensusConfig
extends Resource

## 0=one exact stage, 1=two exact stages, 2=three stage bands.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [5, 7, 8]
@export var success_bonus_damage: Array[int] = [18, 28, 42]
@export var failure_attack_damage: Array[int] = [8, 12, 17]
@export var minimum_target_totals: Array[int] = [2, 2, 2]
@export var teach_stage_pattern: Array[int] = [1, 2, 3, 4, 5]
## Positive means LEFT has more; negative means RIGHT has more.
@export var teach_delta_pattern: Array[int] = [1, -1]
@export var twist_stage_pair_pattern: Array[Vector2i] = [
	Vector2i(1, 2),
	Vector2i(2, 3),
	Vector2i(3, 4),
	Vector2i(4, 5),
]
@export var twist_delta_pattern: Array[Vector2i] = [
	Vector2i(1, -1),
	Vector2i(-1, 1),
]
@export var boss_low_stage_range := Vector2i(1, 2)
@export var boss_mid_stage_range := Vector2i(3, 4)
@export var boss_high_stage_range := Vector2i(5, 7)
@export var boss_delta_pattern: Array[Vector3i] = [
	Vector3i(1, 0, -1),
	Vector3i(-1, 1, 0),
	Vector3i(0, -1, 1),
]
@export_range(0.05, 1.0, 0.05) var live_refresh_interval := 0.15
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65
