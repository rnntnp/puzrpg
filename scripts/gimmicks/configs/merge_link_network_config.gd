class_name MergeLinkNetworkConfig
extends Resource

## 0=single beacon, 1=left-right bridge, 2=three-anchor branch.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var contract_turn_limits: Array[int] = [3, 6, 7]
@export var node_lifetimes: Array[int] = [3, 5, 6]
@export var success_bonus_damage: Array[int] = [16, 24, 34]
@export var failure_attack_damage: Array[int] = [8, 12, 16]
## 0=LEFT, 1=CENTER, 2=RIGHT.
@export var teach_anchor_pattern: Array[int] = [0, 2, 1]
@export_range(60.0, 320.0, 5.0) var node_link_distance := 185.0
@export_range(60.0, 280.0, 5.0) var anchor_reach_distance := 155.0
@export_range(1, 30, 1) var maximum_nodes := 12
@export_range(0.0, 0.25, 0.01) var side_anchor_inset_ratio := 0.06
@export_range(0.2, 0.95, 0.01) var teach_anchor_y_ratio := 0.72
@export_range(0.2, 0.95, 0.01) var twist_anchor_y_ratio := 0.72
@export_range(0.2, 0.95, 0.01) var boss_side_anchor_y_ratio := 0.60
@export_range(0.2, 0.95, 0.01) var boss_center_anchor_y_ratio := 0.84
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65

