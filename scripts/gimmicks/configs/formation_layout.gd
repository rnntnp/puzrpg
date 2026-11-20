extends Resource

@export var display_name := ""
@export var use_wave_positions := false
@export var front_center := Vector2(470, 285)
@export var rear_center := Vector2(615, 285)
@export var front_row_step := Vector2(0, 100)
@export var rear_row_step := Vector2(0, 100)
@export var use_staggered_line := false
@export_range(0.0, 0.5, 0.01) var overlap_ratio := 0.0
@export var line_height := 302.0
@export var line_rise := 9.0
@export var sprite_scale_multiplier := 1.0
@export var slot_offsets := PackedVector2Array()
@export var info_offsets := PackedVector2Array()


func slot_position(saved_position: Vector2, column: int, row: int, row_count: int) -> Vector2:
	if use_wave_positions:
		return saved_position
	var center := front_center if column == 0 else rear_center
	var step := front_row_step if column == 0 else rear_row_step
	return center + step * (row - (row_count - 1) * 0.5)
