extends Resource
## Single convex polygon vertices in centered ShellOutline texture pixels.
@export var stage_03: PackedVector2Array
@export var stage_06: PackedVector2Array

func for_stage(stage: int) -> PackedVector2Array:
	match stage:
		3: return stage_03
		6: return stage_06
	return PackedVector2Array()
