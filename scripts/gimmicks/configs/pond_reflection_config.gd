extends "res://scripts/gimmicks/configs/directional_gravity_config.gd"

@export_range(1.0, 30.0) var reflection_updates_per_second := 12.0
@export_range(12.0, 60.0) var moving_reflection_updates_per_second := 30.0
@export_range(32.0, 400.0) var reflection_reach := 180.0
@export_range(0.0, 2.0) var reflection_strength := 0.60
@export_range(1.0, 32.0) var reflection_exposure := 18.0
@export_range(0.0, 1.0) var highlight_strength := 1.0
@export_range(2.0, 25.0) var highlight_radius_degrees := 12.0
@export_range(0.1, 4.0) var highlight_edge_degrees := 0.8
@export_range(0.0, 1.0) var secondary_highlight_strength := 0.75
@export_range(2.0, 25.0) var secondary_highlight_radius_degrees := 8.0
@export_range(90.0, 270.0) var secondary_highlight_angle_degrees := 180.0
@export_range(0.25, 1.0) var stage_8_highlight_size_scale := 0.80
@export_range(0.01, 0.5) var reflection_roughness := 0.08
@export_range(0.0, 1.0) var environment_strength := 0.035
@export var environment_color := Color(0.30, 0.65, 0.95)
@export var environment_light_directions := PackedVector3Array([Vector3(0.0, -1.0, 0.25), Vector3(1.0, 0.2, 0.30), Vector3(-1.0, 0.35, 0.20)])
@export var environment_light_colors := PackedColorArray([Color(0.55, 0.80, 1.0, 0.16), Color(1.0, 0.82, 0.58, 0.10), Color(0.70, 0.60, 1.0, 0.12)])
