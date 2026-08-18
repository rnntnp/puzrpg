class_name EnemyStanceConfig
extends Resource

## 0=weakness only, 1=attack only, 2=weakness + attack.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1.0, 5.0, 0.05) var weak_multiplier := 1.5
@export_range(1, 10, 1) var stage_loss := 1
