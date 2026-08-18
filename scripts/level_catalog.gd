class_name LevelCatalog
extends Resource

@export_category("Campaign")
@export var campaign_level_paths: Array[String] = []

@export_category("Gimmick Tests")
@export var test_level_paths: Array[String] = []
@export var automated_smoke_level_paths: Array[String] = []


func get_all_level_paths() -> Array[String]:
	var result: Array[String] = campaign_level_paths.duplicate()
	result.append_array(test_level_paths)
	return result


func is_test_level_path(path: String) -> bool:
	return path in test_level_paths
