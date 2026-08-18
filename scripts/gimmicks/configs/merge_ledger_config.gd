class_name MergeLedgerConfig
extends Resource

## 0=global ledger, 1=one active side, 2=both side ledgers.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export var contract_turn_limits: Array[int] = [5, 6, 8]
@export var success_bonus_damage: Array[int] = [16, 24, 34]
@export var failure_attack_damage: Array[int] = [8, 12, 16]
@export var teach_target_pattern: Array[int] = [5, 6, 7]
## 0=LEFT, 1=RIGHT.
@export var twist_side_pattern: Array[int] = [0, 1, 1, 0]
@export var twist_target_pattern: Array[int] = [5, 6, 7]
## Components are LEFT and RIGHT targets.
@export var boss_target_pattern: Array[Vector2i] = [
	Vector2i(5, 7),
	Vector2i(6, 8),
	Vector2i(7, 6),
]
@export_range(0.1, 3.0, 0.05) var result_feedback_duration := 0.65

