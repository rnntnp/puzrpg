class_name MergeAttackEffect
extends Node2D

signal hit(damage: int)

@onready var trail: Line2D = $Trail
@onready var projectile: Sprite2D = $Projectile
@onready var damage_label: Label = $DamageLabel

var _target_position := Vector2.ZERO
var _impact_radius := 0.0
var _impact_alpha := 0.0
var _impact_active := false
var _trail_points: Array[Vector2] = []


func play(from_global: Vector2, to_global: Vector2, data: Resource, damage: int) -> void:
	global_position = from_global
	_target_position = to_global - from_global
	projectile.texture = data.sprite
	projectile.modulate = data.sprite_modulate
	var texture_size: Vector2 = projectile.texture.get_size() if projectile.texture != null else Vector2.ONE
	projectile.scale = Vector2(44.0 / texture_size.x, 44.0 / texture_size.y)
	trail.default_color = data.sprite_modulate
	damage_label.text = "-%d" % damage
	damage_label.position = _target_position + Vector2(-45.0, -24.0)
	damage_label.visible = false

	var flight := create_tween()
	flight.tween_property(projectile, "position", _target_position, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight.finished

	projectile.visible = false
	trail.clear_points()
	_impact_active = true
	_impact_radius = 14.0
	_impact_alpha = 1.0
	damage_label.visible = true
	hit.emit(damage)

	var impact := create_tween().set_parallel(true)
	impact.tween_property(self, "_impact_radius", 58.0, 0.22).set_trans(Tween.TRANS_QUAD)
	impact.tween_property(self, "_impact_alpha", 0.0, 0.22)
	impact.tween_property(damage_label, "position:y", damage_label.position.y - 42.0, 0.32)
	impact.tween_property(damage_label, "modulate:a", 0.0, 0.32)
	await impact.finished
	queue_free()


func _process(_delta: float) -> void:
	if projectile.visible:
		_trail_points.append(projectile.position)
		if _trail_points.size() > 7:
			_trail_points.pop_front()
		trail.points = PackedVector2Array(_trail_points)
	if _impact_active:
		queue_redraw()


func _draw() -> void:
	if not _impact_active or _impact_alpha <= 0.0:
		return
	var color := trail.default_color
	color.a = _impact_alpha
	draw_arc(_target_position, _impact_radius, 0.0, TAU, 32, color, 8.0, true)
