class_name PlayerSkillData
extends Resource

@export_category("스킬 정보")
@export var display_name: String = "약화"
@export var icon: Texture2D

@export_category("게이지")
@export_range(1, 9999, 1) var gauge_max: int = 100

@export_category("약화")
@export_range(1, 20, 1) var weakness_duration_turns: int = 2
