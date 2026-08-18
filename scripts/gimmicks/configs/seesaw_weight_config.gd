class_name SeesawWeightConfig
extends Resource

## 0=basic seesaw, 1=BALANCE CHECK, 2=directional boss target.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [3, 4, 4]
## -1=LEFT HEAVY, 0=BALANCE, 1=RIGHT HEAVY.
@export var boss_target_pattern: Array[int] = [-1, 0, 1, 0]
@export_range(0.0, 0.5, 0.01) var balance_tolerance_ratio := 0.15
@export_range(0.0, 45.0, 0.5) var heavy_tilt_degrees := 10.0
@export_range(0.05, 2.0, 0.05) var tilt_duration := 0.45
@export_range(1.0, 2.5, 0.05) var stage_weight_exponent := 1.25
@export_range(0.0, 0.2, 0.01) var center_neutral_width_ratio := 0.04
@export_range(0.9, 1.25, 0.01) var seesaw_width_ratio := 1.08
@export_range(6.0, 40.0, 1.0) var seesaw_thickness := 18.0
@export_range(0, 999, 1) var success_bonus_damage := 15
@export_range(0, 999, 1) var failure_attack_damage := 18
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
