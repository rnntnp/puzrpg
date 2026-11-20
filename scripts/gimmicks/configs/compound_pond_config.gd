extends "res://scripts/gimmicks/configs/circle_xpbd_pond_config.gd"
## Stage 63 only. Profiles are immutable; every body gets its own shapes.
@export var polygon_profiles: Resource = preload("res://resources/compound_pond_polygon_profiles.tres")
@export_range(0.8, 1.3, 0.01) var collider_size_scale := 1.05
@export_range(8, 32) var compound_max_contacts := 24
## Geometric separation required to release an already observed visual contact.
## Board pixels, before canvas scaling. Does not create new contacts.
@export_range(0.0, 2.0, 0.05) var contact_release_gap := 0.5

@export_group("Collision debug overlay")
@export var show_collision_debug := false
@export var collision_debug_color := Color(0.1, 1.0, 0.85, 0.95)
@export var collision_debug_preview_color := Color(1.0, 0.85, 0.15, 0.95)
@export_range(1.0, 5.0, 0.5) var collision_debug_line_width := 2.0
