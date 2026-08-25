class_name IceSkillData
extends Resource

@export_category("빙결 대상")
@export_range(1, 3, 1) var freeze_count: int = 1
@export_range(1, 11, 1) var target_min_level: int = 1
@export_range(1, 11, 1) var target_max_level: int = 3

@export_category("얼음")
@export_range(1, 9, 1) var ice_durability: int = 2
@export_range(0.0, 2.0, 0.05) var target_highlight_duration: float = 0.25
@export_range(0.0, 2.0, 0.05) var freeze_effect_duration: float = 0.3

@export_category("대상 없음")
@export_range(1.0, 3.0, 0.05) var no_target_damage_multiplier: float = 1.5
