class_name BoardIntrusionConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 10, 1) var telegraph_turns := 3
@export_range(1, 10, 1) var hold_turns := 2
@export_range(0.2, 0.48, 0.01) var arm_length_ratio := 0.36
@export_range(0.03, 0.15, 0.01) var arm_thickness_ratio := 0.065
@export_range(0.15, 0.65, 0.01) var low_height_ratio := 0.34
@export_range(0.25, 0.8, 0.01) var high_height_ratio := 0.53
@export_range(0.05, 2.0, 0.05) var movement_duration := 0.55
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.3

