extends RefCounted

const SAVE_PATH := "user://merge_loadout.cfg"
const LEVEL_PATH := "res://resources/levels/test_merge_loadout.tres"
const NAMES := ["없음", "강타", "수호", "집중", "쇠약"]
const DEFAULTS := [2, 3, 1, 0, 4, 0, 0, 0, 0, 0]

static func read_slots() -> Array[int]:
	var file := ConfigFile.new()
	var loaded := file.load(SAVE_PATH) == OK
	var slots: Array[int] = []
	for index in range(10):
		var value: int = int(file.get_value("slots", str(index), DEFAULTS[index])) if loaded else int(DEFAULTS[index])
		slots.append(clampi(value, 0, NAMES.size() - 1))
	return slots

static func write_slots(slots: Array[int]) -> Error:
	var file := ConfigFile.new()
	for index in range(10):
		file.set_value("slots", str(index), slots[index])
	return file.save(SAVE_PATH)

static func description(stage: int, ability: int, tuning: Resource) -> String:
	match ability:
		1: return "이번 합성 공격 +%d%%" % roundi((tuning.strong_base + stage * tuning.strong_per_stage) * 100.0)
		2: return "보호막 +%d (최대 %d / 적 공격 후 소멸)" % [tuning.guard_base + stage * tuning.guard_per_stage, tuning.guard_cap]
		3: return "다음 합성 공격 +%d%% (최대 %d회 보관)" % [roundi((tuning.focus_base + stage * tuning.focus_per_stage) * 100.0), tuning.focus_cap]
		4: return "적의 다음 공격 -%d%% (가장 강한 효과만)" % roundi(minf(tuning.weaken_cap, tuning.weaken_base + stage * tuning.weaken_per_stage) * 100.0)
	return "기본 합성 공격만 발동"
