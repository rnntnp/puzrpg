extends Node

const DEFAULT_LEVEL_PATH := "res://resources/levels/level_01.tres"
const LevelDataClass = preload("res://scripts/level_data.gd")
const PROGRESS_SAVE_PATH := "user://progress.cfg"
const LEVEL_CATALOG: LevelCatalog = preload("res://resources/catalogs/main_level_catalog.tres")

var level_paths: Array[String] = LEVEL_CATALOG.get_all_level_paths()

var current_level_path := DEFAULT_LEVEL_PATH
var selected_level_index := 0
var highest_completed_level_index := -1
var last_battle_won := false
var last_result_title := ""
var developer_autoplay_enabled := false
var developer_combo_test_requested := false


func _ready() -> void:
	_load_progress()


func set_battle_result(won: bool, title: String) -> void:
	last_battle_won = won
	last_result_title = title


func get_current_level() -> LevelDataClass:
	var level := load(current_level_path) as LevelDataClass
	if level == null:
		push_error("레벨 데이터를 불러올 수 없습니다: %s" % current_level_path)
	return level


func advance_to_next_level() -> bool:
	var current_index := get_current_level_index()
	highest_completed_level_index = maxi(highest_completed_level_index, current_index)
	_save_progress()
	var current_level := get_current_level()
	if current_level == null or current_level.next_level_path.is_empty() or current_index + 1 >= level_paths.size():
		return false
	selected_level_index = current_index + 1
	current_level_path = level_paths[selected_level_index]
	_save_progress()
	return true


func get_level_count() -> int:
	return level_paths.size()


func get_level_at(index: int) -> LevelDataClass:
	if index < 0 or index >= level_paths.size():
		return null
	return load(level_paths[index]) as LevelDataClass


func get_current_level_index() -> int:
	var index := level_paths.find(current_level_path)
	return index if index >= 0 else 0


func is_level_unlocked(index: int) -> bool:
	if index < 0 or index >= level_paths.size():
		return false
	if LEVEL_CATALOG.is_test_level_path(level_paths[index]):
		return true
	return index <= mini(highest_completed_level_index + 1, level_paths.size() - 1)


func select_level(index: int) -> bool:
	if not is_level_unlocked(index):
		return false
	selected_level_index = index
	current_level_path = level_paths[index]
	_save_progress()
	return true


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(PROGRESS_SAVE_PATH) == OK:
		highest_completed_level_index = clampi(
			int(config.get_value("progress", "highest_completed", -1)),
			-1,
			level_paths.size() - 1
		)
		selected_level_index = clampi(
			int(config.get_value("progress", "selected_level", 0)),
			0,
			level_paths.size() - 1
		)
	if not is_level_unlocked(selected_level_index):
		selected_level_index = mini(highest_completed_level_index + 1, level_paths.size() - 1)
	current_level_path = level_paths[selected_level_index]


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "highest_completed", highest_completed_level_index)
	config.set_value("progress", "selected_level", selected_level_index)
	config.save(PROGRESS_SAVE_PATH)


func request_combo_test() -> void:
	developer_combo_test_requested = true


func consume_combo_test_request() -> bool:
	var requested := developer_combo_test_requested
	developer_combo_test_requested = false
	return requested
