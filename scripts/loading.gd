class_name LoadingScreen
extends Control

@export_file("*.tscn") var next_scene_path := "res://scenes/level_select.tscn"
@export_range(0.1, 10.0, 0.1) var display_duration := 1.5

var _display_elapsed := 0.0
var _transition_started := false


func _ready() -> void:
	var error := ResourceLoader.load_threaded_request(next_scene_path)
	if error != OK:
		push_error("다음 화면 비동기 로딩을 시작할 수 없습니다: %s" % next_scene_path)
		set_process(false)
		await get_tree().create_timer(display_duration).timeout
		get_tree().change_scene_to_file(next_scene_path)


func _process(delta: float) -> void:
	if _transition_started:
		return
	_display_elapsed += delta
	if _display_elapsed < display_duration:
		return

	var status := ResourceLoader.load_threaded_get_status(next_scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_transition_to_loaded_scene()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("다음 화면을 불러오지 못했습니다: %s" % next_scene_path)
		_transition_started = true
		get_tree().change_scene_to_file(next_scene_path)


func _transition_to_loaded_scene() -> void:
	_transition_started = true
	var packed_scene := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
	if packed_scene == null:
		push_error("불러온 리소스가 PackedScene이 아닙니다: %s" % next_scene_path)
		get_tree().change_scene_to_file(next_scene_path)
		return

	# 다음 씬의 초기화가 끝날 때까지 현재 타이틀 프레임을 유지한다.
	var next_scene := packed_scene.instantiate()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	queue_free()
