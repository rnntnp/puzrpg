extends Node

const DEFAULT_LEVEL_PATH := "res://resources/levels/level_01.tres"
const LevelDataClass = preload("res://scripts/level_data.gd")

var current_level_path := DEFAULT_LEVEL_PATH
var last_battle_won := false
var last_result_title := ""


func set_battle_result(won: bool, title: String) -> void:
	last_battle_won = won
	last_result_title = title


func get_current_level() -> LevelDataClass:
	var level := load(current_level_path) as LevelDataClass
	if level == null:
		push_error("레벨 데이터를 불러올 수 없습니다: %s" % current_level_path)
	return level


func advance_to_next_level() -> bool:
	var current_level := get_current_level()
	if current_level == null or current_level.next_level_path.is_empty():
		return false
	current_level_path = current_level.next_level_path
	return true
