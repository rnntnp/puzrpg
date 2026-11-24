extends "res://scripts/gimmicks/configs/formation_slot.gd"

@export_range(1, 20, 1) var initial_attack_counter := 3
@export_range(1, 20, 1) var repeat_attack_counter := 3
@export_range(0.0, 1.5, 0.01) var lunge_width_ratio := 0.5
@export_range(0.01, 1.0, 0.01) var lunge_seconds := 0.12
@export_range(0.01, 1.0, 0.01) var return_seconds := 0.18
@export_range(0.0, 1.0, 0.01) var windup_seconds := 0.0
@export_range(0.0, 60.0, 1.0) var windup_degrees := 0.0
@export_range(0.0, 60.0, 1.0) var strike_degrees := 0.0
## Pivot offset from sprite center, as a fraction of its displayed width and height.
@export var attack_pivot_ratio := Vector2.ZERO
