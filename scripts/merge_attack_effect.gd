class_name MergeAttackEffect
extends Node2D

signal hit(damage: int)

@onready var trail: Line2D = $Trail
@onready var trail_glow: Line2D = $TrailGlow
@onready var projectile: Sprite2D = $Projectile
@onready var projectile_glow: Sprite2D = $Projectile/ProjectileGlow
@onready var damage_label: Label = $DamageLabel

var _target_position := Vector2.ZERO
var _impact_radius := 0.0
var _impact_alpha := 0.0
var _impact_active := false
var _trail_points: Array[Vector2] = []
var _impact_target_radius := 58.0
var _combo_count := 1


func play(from_global: Vector2, to_global: Vector2, data: Resource, damage: int, combo_count: int = 1) -> void:
	global_position = from_global
	_target_position = to_global - from_global
	_combo_count = maxi(1, combo_count)
	projectile.texture = data.sprite
	projectile_glow.texture = data.sprite
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	projectile.modulate = data.sprite_modulate
	var texture_size: Vector2 = projectile.texture.get_size() if projectile.texture != null else Vector2.ONE
	var projectile_size := clampf(36.0 + data.get_radius() * 0.22 + float(_combo_count - 1) * 3.0, 42.0, 78.0)
	projectile.scale = Vector2(projectile_size / texture_size.x, projectile_size / texture_size.y)
	trail.default_color = data.glow_color
	trail_glow.default_color = data.glow_color
	trail.width = 9.0 + minf(7.0, float(_combo_count - 1) * 1.5)
	trail_glow.width = 24.0 + minf(18.0, float(_combo_count - 1) * 4.0)
	_impact_target_radius = 54.0 + data.get_radius() * 0.22 + minf(36.0, float(_combo_count - 1) * 8.0)
	damage_label.add_theme_color_override("font_color", data.glow_color.lerp(Color.WHITE, 0.45))
	damage_label.text = "-%d" % damage
	damage_label.position = _target_position + Vector2(-45.0, -24.0)
	damage_label.visible = false

	projectile.rotation = randf_range(-0.2, 0.2)
	var flight := create_tween().set_parallel(true)
	flight.tween_property(projectile, "position", _target_position, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(projectile, "rotation", projectile.rotation + TAU * 1.4, 0.28)
	flight.tween_property(projectile, "scale", projectile.scale * 1.3, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await flight.finished

	projectile.visible = false
	trail.clear_points()
	trail_glow.clear_points()
	_impact_active = true
	_impact_radius = 14.0
	_impact_alpha = 1.0
	damage_label.visible = true
	hit.emit(damage)

	var impact := create_tween().set_parallel(true)
	impact.tween_property(self, "_impact_radius", _impact_target_radius, 0.22).set_trans(Tween.TRANS_QUAD)
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
		trail_glow.points = PackedVector2Array(_trail_points)
	if _impact_active:
		queue_redraw()


func _draw() -> void:
	if not _impact_active or _impact_alpha <= 0.0:
		return
	var color := trail.default_color
	color.a = _impact_alpha
	draw_circle(_target_position, _impact_radius * 0.72, Color(color, _impact_alpha * 0.16))
	draw_arc(_target_position, _impact_radius, 0.0, TAU, 40, color, 8.0, true)
	var hot := color.lerp(Color.WHITE, 0.65)
	hot.a = _impact_alpha
	draw_arc(_target_position, _impact_radius * 0.58, 0.0, TAU, 32, hot, 4.0, true)
	var ray_count := 10 + mini(10, (_combo_count - 1) * 2)
	for index in ray_count:
		var direction := Vector2.from_angle(TAU * float(index) / float(ray_count))
		draw_line(
			_target_position + direction * _impact_radius * 0.35,
			_target_position + direction * _impact_radius * 1.45,
			hot, 3.0, true
		)
