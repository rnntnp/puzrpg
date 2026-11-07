extends "res://scripts/gimmicks/configs/pond_surface_reflection_config.gd"

@export_group("Physics backend")
@export_enum("XPBD", "QuarkPhysics") var physics_backend := "QuarkPhysics"

@export_group("QuarkPhysics")
@export_enum("8:8", "12:12", "16:16") var quark_particle_count := 12
## Native air friction as exponential damping per second; affects all motion.
@export_range(0.0, 12.0) var quark_air_damping := 1.2
@export_range(1, 4) var quark_substeps := 2
@export_range(2, 16) var quark_iterations := 4
@export_range(0.01, 1.0) var quark_rigidity := 0.25
@export_range(0.0, 1.0) var quark_shape_matching := 0.04
@export_range(0.0, 1.0) var quark_area_rigidity := 0.8
@export_range(0.001, 1.0) var quark_sleep_tolerance := 0.025
@export_range(0.0, 1.0) var quark_friction := 0.01
@export_range(0.0, 1.0) var quark_wall_friction := 0.19

@export_group("Soft contact")
@export_range(0.02, 0.25) var maximum_compression := 0.10
@export_range(0.0, 0.3) var contact_bounce := 0.02
## Contact-patch relative velocity damping, in inverse seconds. Zero disables
## this damping; the mandatory inward collision response still remains.
@export_range(0.0, 80.0) var contact_normal_damping := 18.0
@export_range(0.0, 80.0) var contact_tangent_damping := 18.0

@export_group("XPBD")
## Stage 61 collision outline sampling only; visual meshes and six controls stay intact.
@export_range(1, 4) var collision_outline_stride := 1
## Native stage 61 broad phase only; fixed silhouette envelope at registration.
@export_range(1.05, 2.0) var broad_phase_radius_scale := 1.20
@export_range(32.0, 256.0, 8.0) var broad_phase_cell_size := 64.0
@export_range(4, 16) var solver_iterations := 8
@export_range(1, 8) var solver_substeps := 2
@export_range(0.0, 0.02) var edge_compliance := 0.002
@export_range(0.0, 0.02) var shape_compliance := 0.006
@export_range(0.0, 0.01) var area_compliance := 0.000001
@export_range(0.0, 40.0) var internal_damping := 18.0
@export_range(0.1, 20.0) var sleep_velocity := 12.0
@export_range(0.1, 2.0) var sleep_delay := 0.75
