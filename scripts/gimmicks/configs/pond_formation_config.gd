extends "res://scripts/gimmicks/configs/circle_xpbd_pond_config.gd"

const Layout = preload("res://scripts/gimmicks/configs/formation_layout.gd")
const Wave = preload("res://scripts/gimmicks/configs/formation_wave.gd")
const Draft = preload("res://scripts/gimmicks/configs/dungeon_draft_config.gd")

@export_group("Formation")
@export var waves: Array[Wave] = []
@export var layouts: Array[Layout] = []
@export var refill_slots := false
@export var player_position := Vector2(192, 301)
@export_range(0.2, 2.0, 0.05) var player_scale := 0.95
@export_range(0.2, 2.0, 0.05) var enemy_scale := 0.48
@export var draft: Draft
