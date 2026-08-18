class_name StackCoverLaserConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export var attack_intervals: Array[int] = [4, 4, 4]
@export_range(0.35, 0.85, 0.01) var cover_line_safe_height_ratio := 0.60
@export_range(0, 999, 1) var full_laser_damage := 22
@export_range(0.0, 1.0, 0.05) var partial_damage_ratio := 0.50
@export_range(0.05, 1.0, 0.05) var hit_interval := 0.18
@export_range(0.1, 4.0, 0.1) var settle_timeout := 1.5

