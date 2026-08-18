class_name StageFilterBoardConfig
extends Resource

## 0=single filter, 1=left/right filter, 2=swapping left/right filter.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 11, 1) var basic_pass_stage := 2
@export_range(1, 11, 1) var left_pass_stage := 2
@export_range(1, 11, 1) var right_pass_stage := 3
@export_range(1, 20, 1) var swap_interval := 3
@export_range(0.35, 0.8, 0.01) var height_ratio := 0.58
@export_range(2.0, 30.0, 1.0) var platform_thickness := 8.0
@export_range(1.0, 40.0, 1.0) var one_way_margin := 12.0
