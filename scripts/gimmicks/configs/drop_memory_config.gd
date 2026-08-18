class_name DropMemoryConfig
extends Resource

@export var enemy_modes: Array[int] = [0, 1, 2]
@export var attack_intervals: Array[int] = [3, 3, 3]
@export_range(0.0, 1.0, 0.05) var attack_step_interval := 0.15
@export_range(0.0, 2.0, 0.05) var feedback_duration := 0.35

