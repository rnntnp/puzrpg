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
@export var damage_preview_color := Color("#ff8066"):
	set(value):
		damage_preview_color = value
		_refresh_damage_preview_style()

@onready var value_label: Label = $ValueLabel
@onready var value_label_background: TextureRect = $ValueLabelBackground
@onready var full_health_fill: Panel = $FullHealthFill
@onready var durability_fill: Panel = $DurabilityFill
@onready var damage_preview_fill: Panel = $DamagePreviewFill

var current_health := 100
var maximum_health := 100
var predicted_damage := 0
var durability_active := false
var current_durability := 0
var maximum_durability := 1
var _full_fill_size := Vector2.ZERO


func _ready() -> void:
	_full_fill_size = full_health_fill.size
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_aligned else HORIZONTAL_ALIGNMENT_LEFT
	value_label_background.position.x = 130.0 if right_aligned else -22.0
	_refresh_value_text()
	_refresh_fill_style()
	_refresh_durability()
	_refresh_fill_size()
	_refresh_damage_preview_style()
	_refresh_damage_preview()


func set_health(health: int, maximum: int) -> void:
	maximum_health = maxi(1, maximum)
	current_health = clampi(health, 0, maximum_health)
	_refresh_value_text()
	_refresh_fill_size()
	_refresh_damage_preview()


func set_predicted_damage(amount: int) -> void:
	predicted_damage = maxi(0, amount)
	_refresh_damage_preview()


func clear_predicted_damage() -> void:
	set_predicted_damage(0)


func set_durability(value: int, maximum: int) -> void:
	maximum_durability = maxi(1, maximum)
	current_durability = clampi(value, 0, maximum_durability)
	durability_active = true
	_refresh_value_text()
	_refresh_durability()


func clear_durability() -> void:
	durability_active = false
	current_durability = 0
	_refresh_value_text()
	_refresh_durability()


func _refresh_value_text() -> void:
	if is_instance_valid(value_label):
		if durability_active:
			value_label.text = "내구도 %d / %d" % [current_durability, maximum_durability]
		else:
			value_label.text = "%d / %d" % [current_health, maximum_health]


func _refresh_fill_size() -> void:
	if not is_instance_valid(full_health_fill):
		return
	if durability_active:
		full_health_fill.visible = false
		return
	var health_ratio := clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	full_health_fill.visible = health_ratio > 0.0
	if not full_health_fill.visible:
		return
	full_health_fill.size = Vector2(_full_fill_size.x * health_ratio, _full_fill_size.y)


func _refresh_damage_preview() -> void:
	if not is_instance_valid(damage_preview_fill) or not is_instance_valid(full_health_fill):
		return
	var visible_damage := mini(predicted_damage, current_health)
	damage_preview_fill.visible = visible_damage > 0 and current_health > 0
	if not damage_preview_fill.visible:
		return
	var current_ratio := clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	var remaining_ratio := clampf(float(current_health - visible_damage) / float(maximum_health), 0.0, 1.0)
	damage_preview_fill.position = Vector2(
		full_health_fill.position.x + _full_fill_size.x * remaining_ratio,
		full_health_fill.position.y
	)
	damage_preview_fill.size = Vector2(
		_full_fill_size.x * (current_ratio - remaining_ratio),
		_full_fill_size.y
	)
	_refresh_damage_preview_style(
		remaining_ratio <= 0.0001,
		current_ratio >= 0.9999
	)


func _refresh_durability() -> void:
	if not is_instance_valid(durability_fill):
		return
	durability_fill.visible = durability_active and current_durability > 0
	_refresh_fill_size()
	if not durability_fill.visible:
		return
	var durability_ratio := clampf(
		float(current_durability) / float(maximum_durability), 0.0, 1.0
	)
	durability_fill.size = Vector2(_full_fill_size.x * durability_ratio, _full_fill_size.y)

func _refresh_fill_style() -> void:
	if not is_instance_valid(full_health_fill):
		return
	var style := full_health_fill.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(fill_color, 0.94)
	style.border_color = fill_color.lightened(0.20)
	full_health_fill.add_theme_stylebox_override("panel", style)


func _refresh_damage_preview_style(round_left := false, round_right := false) -> void:
	if not is_instance_valid(damage_preview_fill):
		return
	var style := damage_preview_fill.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(damage_preview_color, 0.92)
	style.border_color = damage_preview_color.lightened(0.18)
	style.corner_radius_top_left = 9 if round_left else 0
	style.corner_radius_bottom_left = 9 if round_left else 0
	style.corner_radius_top_right = 9 if round_right else 0
	style.corner_radius_bottom_right = 9 if round_right else 0
	damage_preview_fill.add_theme_stylebox_override("panel", style)
