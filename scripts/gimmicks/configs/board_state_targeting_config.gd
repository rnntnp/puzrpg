class_name BoardStateTargetingConfig
extends Resource

## 0=HEIGHT, 1=COUNT, 2=HEIGHT/COUNT alternation.
@export var enemy_modes: Array[int] = [0, 1, 2]
@export_range(1, 10, 1) var stage_loss := 1
