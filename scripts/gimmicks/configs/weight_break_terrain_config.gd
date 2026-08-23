class_name WeightBreakTerrainConfig
extends Resource

@export_range(1, 20, 1) var glass_rise_action_interval := 5
@export_range(1, 20, 1) var full_glass_attack_interval := 3

@export_category("Enemy 1 / Enemy 3 중앙 유리")
@export_range(1, 100, 1) var crack_stage_sum := 10
@export_range(1, 150, 1) var destroy_stage_sum := 16
## Enemy 1 teaching platform. Enemy 3 keeps its existing glass_width_ratio.
@export_range(0.05, 0.9, 0.01) var enemy1_glass_width_ratio := 0.55
@export_range(0.05, 0.9, 0.01) var glass_width_ratio := 0.40
@export_range(4.0, 30.0, 1.0) var glass_thickness := 10.0
@export_range(1.0, 24.0, 1.0) var support_contact_margin := 8.0
@export_range(0.05, 0.95, 0.01) var c1_height_ratio := 0.70
@export_range(0.05, 0.95, 0.01) var c2_height_ratio := 0.50
@export_range(0.05, 0.95, 0.01) var c3_height_ratio := 0.30

@export_category("Enemy 2 좌우 유리")
@export_range(1, 100, 1) var side_crack_stage_sum := 9
@export_range(1, 150, 1) var side_destroy_stage_sum := 14
@export_range(0.05, 0.40, 0.01) var side_glass_width_ratio := 0.34
@export_range(0.0, 0.30, 0.01) var side_outer_margin_ratio := 0.11
@export_range(0.05, 0.95, 0.01) var side_lower_height_ratio := 0.72
@export_range(0.05, 0.95, 0.01) var side_upper_height_ratio := 0.50

@export_category("공통 물리 / 표시")
@export_range(1.0, 40.0, 1.0) var one_way_margin := 12.0
@export_range(0.1, 4.0, 0.1) var movement_duration := 0.3
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.8
@export_range(0.0, 2.0, 0.05) var collapse_delay := 0.15
