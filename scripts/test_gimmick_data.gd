class_name TestGimmickData
extends Resource

const LegacyVisibility = preload("res://scripts/gimmicks/legacy_gimmick_property_visibility.gd")

enum Kind {
	NONE,
	ENLARGE,
	HEAVY,
	SPLIT,
	DUPLICATE,
	COMPRESS,
	RAISE_FLOOR,
	TILT,
	SHOCKWAVE_VERTICAL,
	SHOCKWAVE_HORIZONTAL,
	ROCK_WALL,
	ROCK_FALL,
	PORTAL,
	GRAVITY_FIELD,
	DANGER_ZONE,
	QUEUE_SHUFFLE,
	SEAL_STAGE,
	WEAKNESS,
	DROP_RESTRICTION,
	SWAP,
	LIFE_BUBBLE,
	FLOOD,
	MERGE_CURSE,
	MERGE_SEQUENCE,
	COMBO_BARRIER,
	TRAPDOOR,
	BUMPER,
	WEAK_ZONE,
	MERGE_ECHO,
	REWIND,
	MIRROR_DROP,
	BOARD_STATE_TARGETING,
	ENEMY_STANCE,
	STAGE_FILTER_BOARD,
	MERGE_DRIVEN_TERRAIN,
	PROFILE_HEIGHT_SHAPING,
	SEESAW_WEIGHT_CENTER,
	WEIGHT_PRESSURE_PLATE,
	STACK_COVER_LASER,
	WEIGHT_BREAK_TERRAIN,
	MERGE_HEAT,
	DROP_MEMORY,
	BOARD_INTRUSION,
}

@export_category("기본")
@export var kind: Kind = Kind.NONE:
	set(value):
		kind = value
		notify_property_list_changed()
@export var display_name := "테스트 기믹"
@export_range(1, 9999, 1) var monster_health := 260
@export_range(0, 999, 1) var normal_attack_damage := 5
@export_range(1, 20, 1) var action_interval := 4
@export_range(1, 20, 1) var normal_attack_interval := 3
@export_range(0, 20, 1) var duration_turns := 0
@export var debug_logging := true

@export_category("Runtime / Level Progression")
## Optional modular runtime. Empty keeps using the legacy compatibility handler.
@export var handler_script: Script:
	set(value):
		handler_script = value
		notify_property_list_changed()
## Handler-specific Inspector values. Modular handlers expose only their own config Resource.
@export var tuning: Resource
## Per-enemy HP overrides. An empty array falls back to monster_health.
@export var enemy_healths: Array[int] = []
## Keeps board-added nodes alive during the delay before the next enemy is configured.
@export var preserve_board_between_enemies := false

@export_category("공 대상")
@export_range(1, 11, 1) var minimum_ball_stage := 1
@export_range(1, 11, 1) var maximum_ball_stage := 3
@export_range(1, 10, 1) var maximum_targets := 2
@export_range(0.1, 4.0, 0.05) var size_multiplier := 1.5
@export_range(0.1, 20.0, 0.1) var mass_multiplier := 4.0
@export_range(0.05, 2.0, 0.05) var animation_duration := 0.5
@export var spawn_offset := Vector2(30.0, -12.0)
@export var initial_velocity := Vector2(80.0, -20.0)

@export_category("보드 물리")
@export_range(0.01, 0.25, 0.01) var board_step_ratio := 0.05
@export_range(1, 5, 1) var maximum_board_steps := 3
@export_range(0.0, 45.0, 1.0) var tilt_degrees := 20.0
@export_range(0.0, 1500.0, 10.0) var impulse_speed := 280.0
@export_range(0.0, 5000.0, 25.0) var field_force := 900.0
@export_range(20.0, 500.0, 5.0) var effect_radius := 180.0

@export_category("장애물/영역")
@export_range(1, 20, 1) var obstacle_durability := 3
@export_range(0.05, 0.5, 0.01) var obstacle_width_ratio := 0.15
@export_range(0.05, 0.5, 0.01) var obstacle_height_ratio := 0.18
@export_range(1, 10, 1) var danger_turn_threshold := 2
@export_range(1, 11, 1) var initial_stage := 2
@export var stage_sequence: Array[int] = []

@export_category("호위")
@export_range(1, 20, 1) var life_health := 3
@export_range(0, 10, 1) var life_max_shield := 1
@export_range(20.0, 500.0, 5.0) var life_shield_radius := 190.0

@export_category("3차 기믹 · 수면/반격")
@export_range(0.05, 0.9, 0.01) var initial_flood_ratio := 0.35
@export_range(0.05, 0.9, 0.01) var maximum_flood_ratio := 0.5
@export_range(0.0, 1.5, 0.05) var buoyancy_ratio := 0.8
@export_range(0.0, 20.0, 0.25) var submerged_linear_damp := 5.0
@export_range(0, 999, 1) var counter_damage := 10

@export_category("3차 기믹 · 합성 규칙")
@export_range(1, 20, 1) var rune_turn_limit := 7
@export_range(1, 20, 1) var rune_restart_delay := 3
@export_range(0, 999, 1) var rune_bonus_damage := 30
@export_range(0.0, 5.0, 0.05) var first_chain_multiplier := 0.25
@export_range(0.0, 5.0, 0.05) var second_chain_multiplier := 1.5
@export_range(0.0, 5.0, 0.05) var later_chain_multiplier := 2.0
@export_range(0.0, 5.0, 0.05) var weak_zone_inside_multiplier := 2.5
@export_range(0.0, 5.0, 0.05) var weak_zone_outside_multiplier := 0.6

@export_category("3차 기믹 · 지형/시간")
@export_range(0.05, 0.5, 0.01) var trapdoor_depth_ratio := 0.15
@export_range(10.0, 200.0, 1.0) var bumper_radius := 42.0
@export_range(0.0, 1500.0, 10.0) var bumper_impulse_speed := 360.0
@export_range(0.0, 2000.0, 10.0) var bumper_max_speed := 620.0
@export_range(0.05, 2.0, 0.05) var bumper_cooldown := 0.25
@export_range(1, 10, 1) var echo_markers_per_turn := 3
@export_range(0.0, 1.0, 0.05) var echo_interval := 0.1
@export_range(0.05, 0.5, 0.01) var rewind_search_ratio := 0.2
@export_range(1, 10, 1) var rewind_target_count := 3
@export_range(1, 11, 1) var mirror_maximum_stage := 3
@export_range(0.0, 1.0, 0.01) var mirror_spawn_delay := 0.15

@export_category("보드 상태 유도 타겟팅")
## 순서대로 몬스터 1, 몬스터 2, 보스의 HP다.
@export var targeting_enemy_healths: Array[int] = [220, 240, 280]
## 0=HEIGHT, 1=COUNT, 2=HEIGHT/COUNT 교대.
@export var targeting_enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 10, 1) var targeting_stage_loss := 1

@export_category("Enemy Stance / Action Induction")
## Sequential monster HP: weakness stance, attack stance, combined boss.
@export var stance_enemy_healths: Array[int] = [220, 240, 280]
## 0=weakness only, 1=attack only, 2=weakness + attack.
@export var stance_enemy_modes: Array[int] = [0, 1, 2]
@export_range(1.0, 5.0, 0.05) var stance_weak_multiplier := 1.5
@export_range(1, 10, 1) var stance_stage_loss := 1

@export_category("Stage Filter Board")
## Sequential monster HP: basic, split, swapping boss.
@export var filter_enemy_healths: Array[int] = [220, 240, 280]
## 0=single filter, 1=left/right filter, 2=swapping left/right filter.
@export var filter_enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 11, 1) var filter_basic_pass_stage := 2
@export_range(1, 11, 1) var filter_left_pass_stage := 2
@export_range(1, 11, 1) var filter_right_pass_stage := 3
@export_range(1, 20, 1) var filter_swap_interval := 3
@export_range(0.35, 0.8, 0.01) var filter_height_ratio := 0.58
@export_range(2.0, 30.0, 1.0) var filter_platform_thickness := 8.0
@export_range(1.0, 40.0, 1.0) var filter_one_way_margin := 12.0


func get_enemy_health(enemy_index: int) -> int:
	if enemy_index >= 0 and enemy_index < enemy_healths.size():
		return maxi(1, enemy_healths[enemy_index])
	return monster_health


func _validate_property(property: Dictionary) -> void:
	var property_name: String = String(property.get("name", ""))
	if property_name == "kind" and handler_script != null:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
		return
	if property_name == "tuning" and handler_script == null:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
		return
	if property_name not in LegacyVisibility.TUNING_PROPERTIES:
		return
	if handler_script != null or property_name not in LegacyVisibility.visible_properties(kind):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
