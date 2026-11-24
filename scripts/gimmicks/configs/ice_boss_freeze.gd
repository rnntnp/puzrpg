extends IceSkillData

enum Kind { SMALL, GIANT }

@export var kind := Kind.SMALL
@export_range(1, 100, 1) var burst_damage := 3
@export_range(1, 999, 1) var backlash_damage := 30
@export_range(0.5, 2.0, 0.05) var burst_visual_scale := 1.0
