class_name IngestionSkillData
extends Resource

@export_category("행동 순서")
@export var start_with_ingestion: bool = false
@export var repeat_ingestion_without_normal_attack: bool = false
@export var alternate_launch_and_heal: bool = false
@export var launch_first: bool = true

@export_category("포식 예고")
@export_range(1, 20, 1) var telegraph_turns: int = 1

@export_category("포식 대응")
@export_range(1, 999, 1) var durability: int = 7
@export_range(0, 999, 1) var durability_increase_per_use: int = 0
@export_range(1, 999, 1) var maximum_durability: int = 7
@export_range(1, 20, 1) var response_turns: int = 3

@export_category("성공 효과")
@export_range(0, 9999, 1) var heal_amount: int = 25
@export_range(0, 9999, 1) var launch_damage: int = 0
@export_range(0, 9999, 1) var launch_damage_increase_per_use: int = 0
@export_range(0, 9999, 1) var maximum_launch_damage: int = 9999

@export_category("저지 효과")
@export_range(0.0, 5.0, 0.05) var interrupted_damage_multiplier: float = 1.3
@export_range(0, 20, 1) var interrupted_debuff_turns: int = 2
