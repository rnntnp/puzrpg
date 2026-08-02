class_name CharacterData
extends Resource

@export_category("기본 정보")
@export var display_name: String = "Fighter"
@export var display_color: Color = Color.WHITE

@export_category("전투 능력치")
@export_range(1, 99999, 1) var max_health: int = 100
@export_range(0, 9999, 1) var attack_power: int = 10
@export_range(1, 20, 1) var enemy_attack_drop_interval: int = 3
