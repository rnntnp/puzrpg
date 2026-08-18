class_name MergeOrderConfig
extends Resource

## 0=zone only, 1=zone + result stage, 2=ordered route.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var turn_limits: Array[int] = [3, 4, 5]
@export var success_bonus_damage: Array[int] = [18, 22, 30]
@export var failure_attack_damage: Array[int] = [10, 14, 18]
@export_range(2, 3, 1) var boss_route_length := 2
@export_range(2, 11, 1) var minimum_requested_result_stage := 2
@export_range(2, 11, 1) var maximum_requested_result_stage := 6
## 0=LEFT, 1=CENTER, 2=RIGHT. Consecutive duplicate entries are skipped.
@export var zone_pattern: Array[int] = [0, 2, 1, 2, 0, 1]

