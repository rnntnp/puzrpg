class_name SplitCascadeConfig
extends Resource

## 0=single split, 1=two simultaneous splits, 2=one two-step cascade.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var action_intervals: Array[int] = [5, 5, 5]
## Bonus damage when Enemy 2 can split only one of its two intended targets.
@export var partial_split_bonus_damage: Array[int] = [0, 5, 0]
## Damage dealt by each successful split action, regardless of target count.
@export var split_damage: Array[int] = [5, 5, 7]
## Final damage when an action cannot split its required target count.
@export var incomplete_split_damage: Array[int] = [10, 10, 10]
@export_range(1, 11, 1) var minimum_target_stage := 3
@export_range(1, 11, 1) var maximum_target_stage := 11
## Enemy 1/2 may split stage 2; the Boss needs stage 3+ for its cascade.
@export var minimum_target_stages: Array[int] = [2, 2, 3]
## Among landed balls, target the highest stage whose top edge is within this distance of the uppermost top edge.

## Enemy 1/2 begin near the parent's X, then separate through diagonal velocity.
@export_range(0.0, 1.0, 0.05) var normal_spawn_offset_radius_ratio := 0.2
@export_range(0.0, 40.0, 1.0) var normal_spawn_min_offset := 8.0
@export_range(0.0, 1.0, 0.05) var normal_spawn_lift_radius_ratio := 0.25
@export_range(0.0, 40.0, 1.0) var normal_sibling_clearance := 10.0
@export_range(0.0, 1.0, 0.05) var normal_sibling_min_grace := 0.3
@export_range(0.1, 1.5, 0.05) var normal_sibling_max_grace := 0.8

## Enemy 1 alone telegraphs, lifts by a relative distance, pauses, then splits.
@export_range(0.0, 1.0, 0.05) var enemy_one_anticipation_duration := 0.15
## Below the low ratio the split uses the high presentation point; above the high
## ratio it uses only the crowded-board relative lift. Values between are blended.
@export_range(0.0, 1.0, 0.05) var enemy_one_stack_low_fill_ratio := 0.45
@export_range(0.0, 1.0, 0.05) var enemy_one_stack_high_fill_ratio := 0.8
@export_range(0.0, 300.0, 5.0) var enemy_one_crowded_lift_base_distance := 80.0
@export_range(0.0, 3.0, 0.05) var enemy_one_crowded_lift_radius_ratio := 0.25
@export_range(0.0, 400.0, 5.0) var enemy_one_crowded_lift_max_distance := 140.0
@export_range(1.0, 2000.0, 10.0) var enemy_one_lift_speed := 400.0
@export_range(0.05, 2.0, 0.05) var enemy_one_lift_min_duration := 0.4
@export_range(0.05, 2.0, 0.05) var enemy_one_lift_max_duration := 1.0
@export_range(0.0, 1.0, 0.05) var enemy_one_arrival_hold_duration := 0.15
@export_range(0.0, 1.0, 0.05) var enemy_one_split_pulse_duration := 0.1
@export_range(0.0, 1.0, 0.05) var enemy_one_recovery_duration := 0.1
@export_range(0.0, 100.0, 1.0) var enemy_one_board_top_margin := 20.0
@export_range(0.0, 100.0, 1.0) var enemy_one_danger_safety_margin := 12.0
## Horizontal presentation point inside the board: 0=left, 0.5=center, 1=right.
@export_range(0.0, 1.0, 0.05) var enemy_one_split_x_ratio := 0.5
@export var enemy_one_split_velocity := Vector2(520.0, 0.0)
@export_range(0.0, 10.0, 0.1) var enemy_one_horizontal_speed_per_radius := 1.5
@export_range(0.0, 1500.0, 10.0) var enemy_one_horizontal_speed_max := 850.0

## Enemy 2 reuses the central airborne split, but processes left then right with
## shorter per-target beats so the complete two-split action stays readable.
@export_range(0.0, 1.0, 0.05) var enemy_two_anticipation_duration := 0.1
@export_range(0.05, 2.0, 0.05) var enemy_two_lift_min_duration := 0.3
@export_range(0.05, 2.0, 0.05) var enemy_two_lift_max_duration := 0.65
@export_range(0.0, 1.0, 0.05) var enemy_two_arrival_hold_duration := 0.1
@export_range(0.0, 1.0, 0.05) var enemy_two_split_pulse_duration := 0.1
@export_range(0.0, 1.0, 0.05) var enemy_two_inter_split_delay := 0.12
@export_range(0.0, 1.0, 0.05) var enemy_two_recovery_duration := 0.1

## Enemy 3 splits once, drops the left first-generation child, then splits only
## the suspended right child again into a horizontally spreading sibling pair.
@export_range(0.0, 1.0, 0.05) var boss_anticipation_duration := 0.15
@export_range(0.05, 2.0, 0.05) var boss_lift_min_duration := 0.35
@export_range(0.05, 2.0, 0.05) var boss_lift_max_duration := 0.75
@export_range(0.0, 1.0, 0.05) var boss_arrival_hold_duration := 0.1
@export_range(0.0, 1.0, 0.05) var boss_first_split_pulse_duration := 0.1
@export var boss_first_split_velocity := Vector2(360.0, 0.0)
@export_range(0.0, 10.0, 0.1) var boss_first_horizontal_speed_per_radius := 1.0
@export_range(0.0, 1500.0, 10.0) var boss_first_horizontal_speed_max := 600.0
@export_range(0.0, 100.0, 1.0) var boss_first_branch_gap := 40.0
@export_range(0.0, 1.0, 0.05) var boss_first_generation_hold := 0.12
@export_range(0.0, 1.0, 0.05) var boss_second_split_pulse_duration := 0.1
@export_range(0.0, 1.0, 0.05) var boss_inter_branch_delay := 0.15
@export_range(0.0, 1.0, 0.05) var boss_recovery_duration := 0.1
