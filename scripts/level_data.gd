class_name LevelData
extends Resource

const CharacterDataClass = preload("res://scripts/character_data.gd")

@export_category("레벨 정보")
@export var level_name: String = "Level"
@export_multiline var image_placeholder: String = "LEVEL IMAGE\nPLACEHOLDER"

@export_category("전투 구성")
@export var player_character: CharacterDataClass
@export var enemies: Array[CharacterDataClass] = []

@export_category("드롭 앤 머지 설정")
## 음수로 설정하면 자동 낙하와 시간제한을 사용하지 않는다.
@export var ball_drop_time_limit: float = 5.0
@export_range(1, 11, 1) var max_ball_level: int = 11

@export_category("진행")
@export_file("*.tres") var next_level_path: String
