class_name StageCrownConfig
extends Resource

## 0=one unique crown, 1=two tied crowns, 2=three-zone staircase.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [5, 7, 8]
@export var success_bonus_damage: Array[int] = [18, 28, 40]
@export var failure_attack_damage: Array[int] = [8, 12, 16]
@export_range(1, 11, 1) var minimum_counted_stage := 1
@export_range(1, 11, 1) var maximum_counted_stage := 9
@export_range(1, 5, 1) var minimum_balls_per_zone := 1
## 0=LEFT, 1=CENTER, 2=RIGHT.
@export var teach_crown_zone_pattern: Array[int] = [0, 1, 2]
@export var twist_crown_pair_pattern: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(0, 1),
	Vector2i(1, 2),
]
## 0=ascending LEFT<CENTER<RIGHT, 1=descending LEFT>CENTER>RIGHT.
@export var boss_direction_pattern: Array[int] = [0, 1]
@export_range(1, 4, 1) var boss_minimum_stage_step := 1
@export_range(0.05, 1.0, 0.05) var live_refresh_interval := 0.15
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65
