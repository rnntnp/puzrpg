extends "res://scripts/gimmicks/configs/pond_formation_config.gd"

const Augments = preload("res://scripts/gimmicks/configs/ice_cave_augments.gd")
@export var augments: Augments = Augments.new()

@export var formation_source: LevelData
## One-based button numbers in the source stage, in wave order.
@export var formation_presets := PackedInt32Array()
@export var ice_boss_source: LevelData
@export_range(0, 2, 1) var ice_boss_index := 0
@export var allow_boss_freeze_at_any_ball_level := false
@export_range(0, 100, 1) var wave_clear_heal := 0
