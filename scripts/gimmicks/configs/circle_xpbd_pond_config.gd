extends "res://scripts/gimmicks/configs/pond_surface_reflection_config.gd"
## Stage 62: ordinary rigid physics, visual-only deformation.
@export_range(0.0, 0.3) var resting_squash := 0.18
@export_range(0.0, 0.15) var impact_squash := 0.12
@export_range(50.0, 1500.0) var impact_speed := 500.0
@export_range(0.0, 0.4) var maximum_warp := 0.28
@export_range(20.0, 600.0) var warp_stiffness := 240.0
@export_range(1.0, 60.0) var warp_damping := 16.0
## Contact starts from its current pose and eases into the pinned target.
@export_range(0.04, 0.4) var press_filter_time := 0.16
## Contact-release pose fades into the spring target instead of disappearing.
@export_range(0.04, 0.5) var release_filter_time := 0.18

@export_group("Visual contact constraints")
@export_range(0.0, 4.0) var wall_padding := 1.0
@export_range(0.0, 12.0) var contact_lookahead := 5.0
@export_range(1, 3) var contact_passes := 2

@export_group("Sprite gloss")
@export var sprite_gloss_texture: Texture2D = preload("res://assets/effects/pond/small_sprite_gloss.svg")
@export_range(0.0,1.0) var sprite_gloss_opacity := 1.0
@export_range(0.10,0.6) var sprite_gloss_width_ratio := 0.30
@export_range(6.0,20.0) var sprite_gloss_min_screen_width := 12.0
@export_range(-90.0,90.0) var sprite_gloss_angle_degrees := -42.0
