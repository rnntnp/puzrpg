class_name MergeDrivenTerrainConfig
extends Resource

## 0=SHELF, 1=DIVIDER, 2=SWITCHING BOSS.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 20, 1) var boss_mode_switch_turns := 3
@export_range(0.15, 0.6, 0.01) var shelf_width_ratio := 0.3
@export_range(0.25, 0.8, 0.01) var shelf_height_ratio := 0.55
@export_range(4.0, 40.0, 1.0) var shelf_thickness := 14.0
@export_range(1.0, 50.0, 1.0) var shelf_one_way_margin := 18.0
@export_range(0.15, 0.75, 0.01) var divider_height_ratio := 0.42
@export_range(4.0, 40.0, 1.0) var divider_thickness := 16.0
@export_range(0.05, 2.0, 0.05) var movement_duration := 0.35
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5
