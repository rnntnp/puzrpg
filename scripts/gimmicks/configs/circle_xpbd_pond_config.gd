extends "res://scripts/gimmicks/configs/pond_surface_reflection_config.gd"
## Stage 62: ordinary rigid physics, visual-only deformation.
@export_range(0.0, 0.3) var resting_squash := 0.18
@export_range(0.0, 0.15) var impact_squash := 0.12
@export_range(50.0, 1500.0) var impact_speed := 500.0
@export_range(0.0, 0.4) var maximum_warp := 0.28
@export_range(20.0, 600.0) var warp_stiffness := 240.0
@export_range(1.0, 60.0) var warp_damping := 16.0
