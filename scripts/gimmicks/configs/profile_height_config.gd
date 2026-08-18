class_name ProfileHeightConfig
extends Resource

## 0=single section, 1=two sections, 2=full-board boss.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var evaluation_intervals: Array[int] = [3, 4, 4]
## 0=LOW, 1=HIGH, -1=ANY. Components are LEFT, CENTER, RIGHT.
@export var single_section_profiles: Array[Vector3i] = [
	Vector3i(0, -1, -1),
	Vector3i(-1, -1, 1),
	Vector3i(-1, 0, -1),
]
@export var dual_section_profiles: Array[Vector3i] = [
	Vector3i(0, -1, 1),
	Vector3i(1, -1, 0),
]
@export var boss_profiles: Array[Vector3i] = [
	Vector3i(0, 1, 0),
	Vector3i(1, 0, 1),
]
## Ratio measured upward from the floor across the safe distance to Danger Line.
@export_range(0.1, 0.9, 0.01) var profile_line_safe_height_ratio := 0.5
@export_range(0, 999, 1) var profile_break_damage := 15
@export_range(0, 999, 1) var profile_miss_damage := 18
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65
@export_range(0.05, 2.0, 0.05) var state_change_feedback_duration := 0.4
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
