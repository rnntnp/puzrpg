@tool
class_name WaterHealthBar
extends Control

@export var fill_color := Color("#58dc70"):
	set(value):
		fill_color = value
		_refresh_fill_style()
@export var accent_color := Color("#9beeff")
@export var heart_color := Color("#ff7fa3")
@export var right_aligned := false

@onready var value_label: Label = $ValueLabel
@onready var value_label_background: TextureRect = $ValueLabelBackground
@onready var full_health_fill: Panel = $FullHealthFill

var current_health := 100
var maximum_health := 100
var _full_fill_size := Vector2.ZERO


func _ready() -> void:
	_full_fill_size = full_health_fill.size
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_aligned else HORIZONTAL_ALIGNMENT_LEFT
	value_label_background.position.x = 130.0 if right_aligned else -22.0
	_refresh_value_text()
	_refresh_fill_style()
	_refresh_fill_size()


func set_health(health: int, maximum: int) -> void:
	maximum_health = maxi(1, maximum)
	current_health = clampi(health, 0, maximum_health)
	_refresh_value_text()
	_refresh_fill_size()


func _refresh_value_text() -> void:
	if is_instance_valid(value_label):
		value_label.text = "%d / %d" % [current_health, maximum_health]


func _refresh_fill_size() -> void:
	if not is_instance_valid(full_health_fill):
		return
	var health_ratio := clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	full_health_fill.visible = health_ratio > 0.0
	if not full_health_fill.visible:
		return
	full_health_fill.size = Vector2(_full_fill_size.x * health_ratio, _full_fill_size.y)

func _refresh_fill_style() -> void:
	if not is_instance_valid(full_health_fill):
		return
	var style := full_health_fill.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(fill_color, 0.94)
	style.border_color = fill_color.lightened(0.20)
	full_health_fill.add_theme_stylebox_override("panel", style)
