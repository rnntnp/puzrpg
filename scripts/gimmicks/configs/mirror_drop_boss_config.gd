class_name MirrorDropBossConfig
extends Resource

@export_range(1, 10, 1) var normal_phase_drops := 3
@export_range(1, 10, 1) var mirror_phase_drops := 3
@export_range(0.0, 1.0, 0.01) var mirror_damage_scale := 0.20
@export_range(0.0, 1.0, 0.01) var mirror_drop_delay := 0.20
@export_range(0.1, 2.0, 0.05) var mirror_merge_quiet_time := 0.50
@export_range(0.0, 1.0, 0.01) var player_turn_return_delay := 0.10
@export_category("Feedback")
@export_range(0.25, 1.0, 0.01) var mirror_landing_pitch_scale := 0.55
@export_range(0.25, 1.0, 0.01) var mirror_merge_pitch_scale := 0.62
@export_range(1.0, 2.0, 0.05) var mirror_merge_effect_scale := 1.35
@export var mirror_merge_effect_color := Color("#111522")
