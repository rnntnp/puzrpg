extends Node

const BGM_BUS := &"BGM"
const SFX_BUS := &"SFX"
const SETTINGS_PATH := "user://audio_settings.cfg"

var bgm_volume := 0.8
var sfx_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BGM_BUS)
	_ensure_bus(SFX_BUS)
	_load_settings()
	_apply_bus_volume(BGM_BUS, bgm_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)
	get_tree().node_added.connect(_on_node_added)
	_route_audio_players(get_tree().root)


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BGM_BUS, bgm_volume)
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS, sfx_volume)
	_save_settings()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))


func _on_node_added(node: Node) -> void:
	_route_audio_player(node)


func _route_audio_players(node: Node) -> void:
	_route_audio_player(node)
	for child in node.get_children():
		_route_audio_players(child)


func _route_audio_player(node: Node) -> void:
	if not node is AudioStreamPlayer:
		return
	var player := node as AudioStreamPlayer
	if player.bus != &"Master":
		return
	var normalized_name := String(player.name).to_lower()
	player.bus = BGM_BUS if "music" in normalized_name or "bgm" in normalized_name else SFX_BUS


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("소리 설정을 불러오지 못했습니다: %s" % error_string(error))
		return
	bgm_volume = _read_volume(config, "bgm", bgm_volume)
	sfx_volume = _read_volume(config, "sfx", sfx_volume)


func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value("audio", key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", bgm_volume)
	config.set_value("audio", "sfx", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("소리 설정을 저장하지 못했습니다: %s" % error_string(error))
