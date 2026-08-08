class_name BallCatalog
extends RefCounted

const BALLS := [
	preload("res://resources/balls/ball_01.tres"),
	preload("res://resources/balls/ball_02.tres"),
	preload("res://resources/balls/ball_03.tres"),
	preload("res://resources/balls/ball_04.tres"),
	preload("res://resources/balls/ball_05.tres"),
	preload("res://resources/balls/ball_06.tres"),
	preload("res://resources/balls/ball_07.tres"),
	preload("res://resources/balls/ball_08.tres"),
	preload("res://resources/balls/ball_09.tres"),
	preload("res://resources/balls/ball_10.tres"),
	preload("res://resources/balls/ball_11.tres"),
]


static func get_ball(level_index: int) -> Resource:
	return BALLS[clampi(level_index, 0, BALLS.size() - 1)]


static func get_max_level_index() -> int:
	return BALLS.size() - 1
