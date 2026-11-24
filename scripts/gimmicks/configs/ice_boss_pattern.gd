extends Resource

const Freeze = preload("res://scripts/gimmicks/configs/ice_boss_freeze.gd")

@export var character: CharacterData
@export var first_freeze: Freeze
@export var second_freeze: Freeze
@export_range(1, 20, 1) var initial_attack_turns := 2
@export_range(1, 20, 1) var turns_before_freeze := 3
@export_range(1, 20, 1) var turns_between_freezes := 2
@export_range(1, 20, 1) var burst_turns := 4
@export_range(1, 20, 1) var turns_after_burst := 2
