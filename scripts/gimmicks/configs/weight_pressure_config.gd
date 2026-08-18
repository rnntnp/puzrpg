class_name WeightPressureConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [4, 4, 4]
@export_range(1, 10, 1) var both_check_interval := 5
@export_range(1.0, 100.0, 0.5) var required_weight := 25.0
@export_range(0.2, 0.48, 0.01) var plate_width_ratio := 0.38
@export_range(1.0, 2.5, 0.05) var stage_weight_exponent := 1.25
@export_range(0, 999, 1) var success_bonus_damage := 15
@export_range(0, 999, 1) var failure_attack_damage := 18
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
@export_range(0.1, 2.0, 0.05) var feedback_duration := 0.6

