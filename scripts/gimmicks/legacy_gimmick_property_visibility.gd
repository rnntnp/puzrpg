class_name LegacyGimmickPropertyVisibility
extends RefCounted

const TUNING_PROPERTIES := [
	"minimum_ball_stage", "maximum_ball_stage", "maximum_targets", "size_multiplier",
	"mass_multiplier", "animation_duration", "spawn_offset", "initial_velocity",
	"board_step_ratio", "maximum_board_steps", "tilt_degrees", "impulse_speed",
	"field_force", "effect_radius", "obstacle_durability", "obstacle_width_ratio",
	"obstacle_height_ratio", "danger_turn_threshold", "initial_stage", "stage_sequence",
	"life_health", "life_max_shield", "life_shield_radius", "initial_flood_ratio",
	"maximum_flood_ratio", "buoyancy_ratio", "submerged_linear_damp", "counter_damage",
	"rune_turn_limit", "rune_restart_delay", "rune_bonus_damage", "first_chain_multiplier",
	"second_chain_multiplier", "later_chain_multiplier", "weak_zone_inside_multiplier",
	"weak_zone_outside_multiplier", "trapdoor_depth_ratio", "bumper_radius",
	"bumper_impulse_speed", "bumper_max_speed", "bumper_cooldown",
	"echo_markers_per_turn", "echo_interval", "rewind_search_ratio",
	"rewind_target_count", "mirror_maximum_stage", "mirror_spawn_delay",
	"targeting_enemy_healths", "targeting_enemy_modes", "targeting_stage_loss",
	"stance_enemy_healths", "stance_enemy_modes", "stance_weak_multiplier",
	"stance_stage_loss", "filter_enemy_healths", "filter_enemy_modes",
	"filter_basic_pass_stage", "filter_left_pass_stage", "filter_right_pass_stage",
	"filter_swap_interval", "filter_height_ratio", "filter_platform_thickness",
	"filter_one_way_margin",
]


static func visible_properties(kind: int) -> Array:
	var shared_animation: Array[String] = ["animation_duration"]
	match kind:
		1: # ENLARGE
			return shared_animation + ["minimum_ball_stage", "maximum_ball_stage", "maximum_targets", "size_multiplier"]
		2: # HEAVY
			return ["minimum_ball_stage", "maximum_ball_stage", "maximum_targets", "mass_multiplier"]
		3: # SPLIT
			return ["minimum_ball_stage", "maximum_ball_stage", "spawn_offset", "initial_velocity"]
		4: # DUPLICATE
			return ["minimum_ball_stage", "maximum_ball_stage"]
		5, 6: # COMPRESS, RAISE_FLOOR
			return shared_animation + ["board_step_ratio", "maximum_board_steps"]
		7: # TILT
			return shared_animation + ["tilt_degrees"]
		8, 9: # SHOCKWAVE_VERTICAL, SHOCKWAVE_HORIZONTAL
			return ["impulse_speed"]
		10, 11: # ROCK_WALL, ROCK_FALL
			return shared_animation + ["maximum_targets", "effect_radius", "obstacle_durability", "obstacle_width_ratio", "obstacle_height_ratio"]
		13: # GRAVITY_FIELD
			return ["field_force", "effect_radius"]
		14: # DANGER_ZONE
			return ["danger_turn_threshold"]
		16: # SEAL_STAGE
			return ["stage_sequence"]
		17: # WEAKNESS
			return ["initial_stage", "stage_sequence"]
		19: # SWAP
			return shared_animation
		20: # LIFE_BUBBLE
			return ["life_health", "life_max_shield", "life_shield_radius"]
		21: # FLOOD
			return shared_animation + ["initial_flood_ratio", "maximum_flood_ratio", "buoyancy_ratio", "submerged_linear_damp"]
		22: # MERGE_CURSE
			return ["minimum_ball_stage", "maximum_ball_stage", "counter_damage"]
		23: # MERGE_SEQUENCE
			return ["rune_turn_limit", "rune_restart_delay", "rune_bonus_damage"]
		24: # COMBO_BARRIER
			return ["first_chain_multiplier", "second_chain_multiplier", "later_chain_multiplier"]
		25: # TRAPDOOR
			return shared_animation + ["trapdoor_depth_ratio"]
		26: # BUMPER
			return ["bumper_radius", "bumper_impulse_speed", "bumper_max_speed", "bumper_cooldown"]
		27: # WEAK_ZONE
			return ["weak_zone_inside_multiplier", "weak_zone_outside_multiplier"]
		28: # MERGE_ECHO
			return ["impulse_speed", "effect_radius", "echo_markers_per_turn", "echo_interval"]
		29: # REWIND
			return shared_animation + ["rewind_search_ratio", "rewind_target_count"]
		30: # MIRROR_DROP
			return ["mirror_maximum_stage", "mirror_spawn_delay"]
		31: # BOARD_STATE_TARGETING
			return ["targeting_enemy_healths", "targeting_enemy_modes", "targeting_stage_loss"]
		32: # ENEMY_STANCE
			return ["stance_enemy_healths", "stance_enemy_modes", "stance_weak_multiplier", "stance_stage_loss"]
		33: # STAGE_FILTER_BOARD
			return ["filter_enemy_healths", "filter_enemy_modes", "filter_basic_pass_stage", "filter_left_pass_stage", "filter_right_pass_stage", "filter_swap_interval", "filter_height_ratio", "filter_platform_thickness", "filter_one_way_margin"]
		_:
			return []
