extends "res://scripts/gimmicks/configs/normal_monster_slot.gd"

@export_range(1, 20, 1) var shield_counter := 2
@export_range(1, 20, 1) var shield_duration := 3
## One-based positions in the wave's slots array.
@export var protection_order := PackedInt32Array()
@export var rotate_protection_order := false
