class_name MergeHeatConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export var check_intervals: Array[int] = [3, 4, 4]
@export_range(1, 500, 1) var maximum_heat := 100
@export_range(0, 500, 1) var starting_heat := 0
@export_range(1, 100, 1) var warm_threshold := 30
@export_range(1, 100, 1) var hot_threshold := 70
@export_range(0, 100, 1) var heat_per_merge := 12
@export_range(0, 100, 1) var cooling_per_empty_drop := 25
@export_range(0.0, 5.0, 0.05) var cool_damage_multiplier := 1.0
@export_range(0.0, 5.0, 0.05) var warm_damage_multiplier := 1.1
@export_range(0.0, 5.0, 0.05) var hot_damage_multiplier := 1.25
@export_range(0, 999, 1) var success_bonus_damage := 18
@export_range(0, 999, 1) var failure_attack_damage := 20
@export_range(0.1, 2.0, 0.05) var feedback_duration := 0.6

