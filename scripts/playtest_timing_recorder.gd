class_name PlaytestTimingRecorder
extends Node

const CSV_PATH := "user://playtest_stage_timings.csv"
const CSV_HEADER: Array[String] = [
	"recorded_at",
	"attempt_id",
	"event",
	"level_path",
	"level_name",
	"control_mode",
	"enemy_index",
	"enemy_total",
	"enemy_name",
	"segment_seconds",
	"cumulative_seconds",
]

var _enabled := false
var _attempt_finished := false
var _combat_active := false
var _last_tick_usec := 0
var _total_active_usec := 0
var _enemy_segment_start_usec := 0
var _attempt_id := ""
var _level_path := ""
var _level_name := ""
var _control_mode := "manual"
var _enemy_index := -1
var _enemy_total := 0
var _enemy_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func start_attempt(
	level_path: String,
	level_name: String,
	enemy_total: int,
	autoplay_enabled: bool
) -> void:
	_enabled = (
		OS.is_debug_build()
		and OS.get_cmdline_user_args().has("--playtest-timing")
	)
	# _enabled = OS.is_debug_build() # F5 플레이테스트 시에만 이 줄의 주석을 해제한다.
	_attempt_finished = false
	_combat_active = false
	_last_tick_usec = Time.get_ticks_usec()
	_total_active_usec = 0
	_enemy_segment_start_usec = 0
	_attempt_id = "%s-%d" % [
		Time.get_datetime_string_from_system(false, false),
		_last_tick_usec,
	]
	_level_path = level_path
	_level_name = level_name
	_control_mode = "autoplay" if autoplay_enabled else "manual"
	_enemy_index = -1
	_enemy_total = maxi(0, enemy_total)
	_enemy_name = ""
	set_process(_enabled)
	if not _enabled:
		return
	print(
		"[PLAYTEST TIMING] START | stage=%s | enemies=%d | mode=%s | csv=%s" % [
			_level_name,
			_enemy_total,
			_control_mode,
			ProjectSettings.globalize_path(CSV_PATH),
		]
	)


func begin_enemy(enemy_index: int, enemy_name: String) -> void:
	if not _enabled or _attempt_finished:
		return
	_capture_active_time()
	_enemy_index = enemy_index
	_enemy_name = enemy_name


func set_combat_active(active: bool) -> void:
	if not _enabled or _attempt_finished:
		return
	_capture_active_time()
	_combat_active = active


func record_enemy_defeated() -> void:
	if not _enabled or _attempt_finished or _enemy_index < 0:
		return
	_capture_active_time()
	_combat_active = false
	var segment_usec := maxi(0, _total_active_usec - _enemy_segment_start_usec)
	var segment_seconds := float(segment_usec) / 1_000_000.0
	var cumulative_seconds := float(_total_active_usec) / 1_000_000.0
	_append_event(
		"enemy_defeated",
		str(_enemy_index + 1),
		_enemy_name,
		"%.3f" % segment_seconds,
		"%.3f" % cumulative_seconds
	)
	print(
		"[PLAYTEST TIMING] ENEMY %d/%d DEFEATED | name=%s | segment=%.3fs | cumulative=%.3fs" % [
			_enemy_index + 1,
			_enemy_total,
			_enemy_name,
			segment_seconds,
			cumulative_seconds,
		]
	)
	_enemy_segment_start_usec = _total_active_usec


func finish_attempt(outcome: String) -> void:
	if not _enabled or _attempt_finished:
		return
	_capture_active_time()
	_combat_active = false
	_attempt_finished = true
	var cumulative_seconds := float(_total_active_usec) / 1_000_000.0
	_append_event(
		outcome,
		str(_enemy_index + 1) if _enemy_index >= 0 else "",
		_enemy_name,
		"",
		"%.3f" % cumulative_seconds
	)
	print(
		"[PLAYTEST TIMING] %s | stage=%s | cumulative=%.3fs" % [
			outcome.to_upper(),
			_level_name,
			cumulative_seconds,
		]
	)
	set_process(false)


func _process(_delta: float) -> void:
	_capture_active_time()


func _exit_tree() -> void:
	if _enabled and not _attempt_finished:
		finish_attempt("abandoned")


func _capture_active_time() -> void:
	var now_usec := Time.get_ticks_usec()
	var tree_paused := get_tree().paused if is_inside_tree() else false
	if _combat_active and not tree_paused:
		_total_active_usec += maxi(0, now_usec - _last_tick_usec)
	_last_tick_usec = now_usec


func _append_event(
	event_name: String,
	enemy_index_text: String,
	enemy_name: String,
	segment_seconds: String,
	cumulative_seconds: String
) -> void:
	var recorded_at := Time.get_datetime_string_from_system(false, true)
	var row := PackedStringArray([
		recorded_at,
		_attempt_id,
		event_name,
		_level_path,
		_level_name,
		_control_mode,
		enemy_index_text,
		str(_enemy_total),
		enemy_name,
		segment_seconds,
		cumulative_seconds,
	])
	var file_exists := FileAccess.file_exists(CSV_PATH)
	var access_mode := FileAccess.READ_WRITE if file_exists else FileAccess.WRITE
	var file := FileAccess.open(CSV_PATH, access_mode)
	if file == null:
		push_warning("플레이테스트 시간 CSV를 열 수 없습니다: %s" % CSV_PATH)
		return
	var needs_header := not file_exists or file.get_length() == 0
	file.seek_end()
	if needs_header:
		file.store_csv_line(PackedStringArray(CSV_HEADER))
	file.store_csv_line(row)
	file.flush()
