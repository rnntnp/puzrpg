extends "res://scripts/gimmicks/configs/pond_surface_reflection_config.gd"

@export_group("Soft contact")
@export_range(0.02, 0.25) var maximum_compression := 0.10
@export_range(0.0, 0.3) var contact_bounce := 0.02

@export_group("XPBD")
@export_range(4, 16) var solver_iterations := 8
@export_range(1, 8) var solver_substeps := 2
@export_range(0.0, 0.02) var edge_compliance := 0.002
@export_range(0.0, 0.02) var shape_compliance := 0.006
@export_range(0.0, 0.01) var area_compliance := 0.000001
@export_range(0.0, 40.0) var internal_damping := 18.0
@export_range(0.1, 20.0) var sleep_velocity := 12.0
@export_range(0.1, 2.0) var sleep_delay := 0.75
