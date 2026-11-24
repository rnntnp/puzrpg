extends "res://scripts/gimmicks/configs/soft_pond_config.gd"
## Stage 64: real particle contacts; no stage-62 visual-only contact correction.
@export_group("Object pool")
@export_range(0, 12, 1) var pool_spares_per_level := 4
@export_range(1, 24, 1) var pool_retained_per_level := 8
@export_range(16, 128, 16) var burst_initial_capacity := 64
@export_group("Internal motion")
## Damps deformation velocity while preserving translation and rigid rotation.
@export_range(0.0, 60.0, 1.0) var particle_internal_damping := 24.0
@export_group("Bounded deformation")
## Screen-pixel clearance added to the native physical silhouette only.
@export_range(0.0, 30.0, 1.0) var collision_padding_px := 4.0
@export var bounded_deformation := true
@export_range(1.0, 1.5, 0.01) var deformation_soft_ratio := 1.035
@export_range(1.01, 2.0, 0.01) var deformation_hard_ratio := 1.07
## Maximum deviation from the matching rotated rest silhouette, as radius ratio.
@export_range(0.0, 0.3, 0.01) var particle_deformation_limit := 0.07
@export_range(1.0, 30.0, 0.5) var deformation_return_rate := 12.0
@export var spatial_partition := true
@export var centroid_bound_search := true
@export_range(32.0, 256.0, 8.0) var spatial_cell_size := 128.0
@export_group("Presentation")
@export_range(0.0, 7.0, 0.25) var cut_border_width_px := 3.0
@export_range(0.0, 1.0, 0.05) var face_strain_weight := 0.15
@export var show_soft_debug := true
@export var soft_debug_color := Color(0.1, 1.0, 0.85, 0.95)
