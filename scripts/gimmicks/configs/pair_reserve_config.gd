class_name PairReserveConfig
extends Resource

## 0=one global pair stage, 1=multiple global pair stages, 2=one pair stage per side.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [4, 6, 7]
@export var success_bonus_damage: Array[int] = [18, 26, 36]
@export var failure_attack_damage: Array[int] = [8, 12, 16]
@export_range(1, 11, 1) var minimum_reserve_stage := 1
@export_range(1, 11, 1) var maximum_reserve_stage := 7
@export_range(1, 3, 1) var teach_required_pair_stages := 1
@export_range(2, 5, 1) var twist_required_pair_stages := 2
@export var exclude_previous_success_stages := true
@export var boss_requires_different_side_stages := true
@export_range(0.05, 1.0, 0.05) var live_refresh_interval := 0.15
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65

