class_name IngestionSkillData
extends Resource

@export_category("포식 예고")
@export_range(1, 20, 1) var telegraph_turns: int = 1

@export_category("포식 대응")
@export_range(1, 999, 1) var durability: int = 7
@export_range(1, 20, 1) var response_turns: int = 3

@export_category("성공 효과")
@export_range(0, 9999, 1) var heal_amount: int = 25

@export_category("저지 효과")
@export_range(0.0, 5.0, 0.05) var interrupted_damage_multiplier: float = 1.3
@export_range(0, 20, 1) var interrupted_debuff_turns: int = 2
