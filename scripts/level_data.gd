class_name LevelData
extends Resource

const CharacterDataClass = preload("res://scripts/character_data.gd")

@export_category("레벨 정보")
@export var level_name: String = "Level"
@export_multiline var image_placeholder: String = "LEVEL IMAGE\nPLACEHOLDER"

@export_category("전투 구성")
@export var player_character: CharacterDataClass
@export var enemies: Array[CharacterDataClass] = []

@export_category("진행")
@export_file("*.tres") var next_level_path: String
