class_name WaterHealthBar
extends Control

@export var fill_color := Color("#58dc70")
@export var accent_color := Color("#9beeff")
@export var heart_color := Color("#ff7fa3")
@export var right_aligned := false

@onready var value_label: Label = $ValueLabel

var current_health := 100
var maximum_health := 100


func _ready() -> void:
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_aligned else HORIZONTAL_ALIGNMENT_LEFT
	_refresh_value_text()
	queue_redraw()


func set_health(health: int, maximum: int) -> void:
	maximum_health = maxi(1, maximum)
	current_health = clampi(health, 0, maximum_health)
	_refresh_value_text()
	queue_redraw()


func _refresh_value_text() -> void:
	if is_instance_valid(value_label):
		value_label.text = "%d / %d" % [current_health, maximum_health]


func _draw() -> void:
	# The reference-derived translucent sprite is drawn above this dynamic liquid.
	var inner_rect := Rect2(55.0, 28.0, 202.0, 18.0)
	var health_ratio := clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	if health_ratio <= 0.0:
		return

	var fill_rect := inner_rect
	fill_rect.size.x *= health_ratio
	var liquid_style := _create_style(Color(fill_color, 0.94), fill_color.lightened(0.20), 1, 9)
	draw_style_box(liquid_style, fill_rect)


func _create_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style
