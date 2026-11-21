extends "res://scripts/gimmicks/configs/circle_xpbd_pond_config.gd"

const Layout = preload("res://scripts/gimmicks/configs/formation_layout.gd")
const Wave = preload("res://scripts/gimmicks/configs/formation_wave.gd")
const Draft = preload("res://scripts/gimmicks/configs/dungeon_draft_config.gd")

@export_group("Formation")
@export var waves: Array[Wave] = []
@export var layouts: Array[Layout] = []
@export var refill_slots := false
@export var preview_action_icons := false
@export_range(0.0, 100.0, 1.0) var player_enemy_gap := 42.0
@export_range(0.2, 2.0, 0.05) var enemy_scale := 0.48
@export var draft: Draft

@export_group("Turn Attack Presentation")
@export_range(0.1, 3.0, 0.05) var settlement_quiet_seconds := 1.0
@export_range(0.1, 1.5, 0.01) var seconds_per_target := 0.36
@export_range(0.1, 3.0, 0.01) var minimum_attack_seconds := 0.22
@export_range(0.1, 4.0, 0.01) var maximum_attack_seconds := 1.40
@export_range(0.1, 5.0, 0.05) var acceleration_after_seconds := 1.1
@export_range(1.0, 4.0, 0.05) var maximum_attack_speed := 1.5
@export_range(0.0, 1.0, 0.01) var counterattack_seconds := 0.58
@export_range(1.0, 500.0, 1.0) var effect_damage_reference := 50.0
@export_range(0.1, 3.0, 0.05) var minimum_effect_strength := 0.75
@export_range(0.1, 4.0, 0.05) var maximum_effect_strength := 1.6
@export_range(0.01, 0.2, 0.01) var impact_flash_seconds := 0.07
@export_range(0.1, 1.0, 0.05) var impact_flash_opacity := 0.65
@export_range(0.0, 24.0, 1.0) var recoil_distance := 10.0
@export_range(0.03, 0.4, 0.01) var recoil_return_seconds := 0.14
@export_range(10.0, 60.0, 1.0) var impact_ring_radius := 29.0
@export_range(0.05, 0.8, 0.01) var impact_ring_seconds := 0.24
@export_range(1, 20, 1) var impact_particle_count := 7
@export_range(1.0, 8.0, 0.25) var impact_particle_size := 3.0
@export_range(16, 60, 1) var damage_font_size := 32
@export_range(0.0, 1.0, 0.05) var damage_font_growth := 0.24
@export_range(0.1, 1.0, 0.01) var damage_hold_seconds := 0.28
@export_range(0.05, 1.0, 0.01) var damage_fade_seconds := 0.24
