extends "res://scripts/gimmicks/configs/normal_monster_slot.gd"

@export_range(0.0, 4.0, 0.05) var incoming_damage_bonus := 0.50
@export_range(1, 20, 1) var weakness_duration := 3
@export_range(0.0, 0.2, 0.01) var hover_height_ratio := 0.03
@export_range(0.2, 5.0, 0.01) var hover_period := 2.0
@export_range(1.0, 1.5, 0.01) var cast_scale := 1.10
@export_range(0.01, 1.0, 0.01) var swell_seconds := 0.15
@export_range(0.01, 1.0, 0.01) var settle_seconds := 0.20
