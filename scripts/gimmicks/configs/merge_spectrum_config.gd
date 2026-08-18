class_name MergeSpectrumConfig
extends Resource

## 0=any two categories, 1=specified pair, 2=all categories.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var contract_turn_limits: Array[int] = [4, 5, 6]
@export var success_bonus_damage: Array[int] = [16, 24, 34]
@export var failure_attack_damage: Array[int] = [8, 12, 16]
@export_range(2, 9, 1) var low_maximum_result_stage := 3
@export_range(3, 10, 1) var mid_maximum_result_stage := 4
## Category values: 0=LOW, 1=MID, 2=HIGH.
@export var twist_required_pairs: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 2),
	Vector2i(0, 2),
]
@export_range(2, 3, 1) var teach_required_distinct_categories := 2
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65

