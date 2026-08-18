class_name WeightBreakTerrainConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1.0, 100.0, 0.5) var standard_break_weight := 25.0
@export_range(1.0, 120.0, 0.5) var lower_break_weight := 30.0
@export_range(1.0, 2.5, 0.05) var stage_weight_exponent := 1.25
@export_range(0.4, 0.9, 0.01) var single_floor_width_ratio := 0.68
@export_range(0.25, 0.48, 0.01) var split_floor_width_ratio := 0.42
@export_range(0.45, 0.8, 0.01) var single_floor_height_ratio := 0.60
@export_range(0.25, 0.65, 0.01) var upper_floor_height_ratio := 0.42
@export_range(0.55, 0.85, 0.01) var lower_floor_height_ratio := 0.68
@export_range(4.0, 30.0, 1.0) var platform_thickness := 10.0
@export_range(1.0, 40.0, 1.0) var one_way_margin := 12.0
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.8
@export_range(0.0, 2.0, 0.05) var collapse_delay := 0.15

