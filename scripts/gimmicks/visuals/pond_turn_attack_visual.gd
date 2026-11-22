extends Node2D

const NUMBER_FONT = preload("res://assets/fonts/nanum_square_round/NanumSquareRoundEB.ttf")
const Config = preload("res://scripts/gimmicks/configs/pond_formation_config.gd")
const TRAVEL_FRACTION := 0.30

class Impact:
	var position: Vector2
	var number_origin: Vector2
	var strength: float
	var age := 0.0
	var defeated := false
	var label: Label

var participants: Array[MergeBall] = []
var firing_balls: Array[MergeBall] = []
var origins := PackedVector2Array()
var volley_targets := PackedVector2Array()
var volley_strengths := PackedFloat32Array()
var spread_volley := false
var intensity := 0.0
var shot_start_msec := 0
var shot_duration := 0.0
var impacts: Array[Impact] = []
var tuning: Config
var flash_shader := Shader.new()


func _ready() -> void:
	z_index = 210
	flash_shader.code = "shader_type canvas_item; void fragment() { COLOR = vec4(0.87, 0.97, 1.0, COLOR.a); }"


func track_ball(ball: MergeBall) -> void:
	participants.append(ball)


func take_origins() -> PackedVector2Array:
	_prune_balls()
	var points := PackedVector2Array()
	for ball in participants:
		points.append(ball.global_position)
	firing_balls.assign(participants)
	participants.clear()
	return points


func start_volley(points: PackedVector2Array, endpoints: PackedVector2Array, amounts: PackedInt32Array, duration: float, spread: bool) -> void:
	origins = points
	volley_targets = endpoints
	spread_volley = spread
	volley_strengths.clear()
	intensity = 0.0
	for damage in amounts:
		var strength := _damage_strength(damage)
		volley_strengths.append(strength)
		intensity = maxf(intensity, strength)
	shot_duration = duration
	shot_start_msec = Time.get_ticks_msec()


func _damage_strength(damage: int) -> float:
	return clampf(sqrt(float(damage) / tuning.effect_damage_reference),
		tuning.minimum_effect_strength, maxf(tuning.minimum_effect_strength, tuning.maximum_effect_strength))


func show_impact(fighter: Fighter, damage: int, defeated: bool) -> void:
	var target := fighter.character_sprite.global_position
	var hit := Impact.new()
	hit.position = to_local(target)
	hit.strength = _damage_strength(damage)
	_flash_and_recoil(fighter, target, hit.strength, defeated)
	hit.defeated = defeated
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(damage)
	label.add_theme_font_override("font", NUMBER_FONT)
	label.add_theme_color_override("font_color", Color("#ffe981") if defeated else Color("#fff8d3"))
	label.add_theme_color_override("font_outline_color", Color("#21132f"))
	label.add_theme_constant_override("outline_size", 9)
	var font_scale := 1.0 + (hit.strength - 1.0) * tuning.damage_font_growth
	label.add_theme_font_size_override("font_size", clampi(roundi(tuning.damage_font_size * font_scale + (4 if defeated else 0)), 24, 52))
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	hit.number_origin = _find_number_origin(hit.position, label.size)
	hit.label = label
	impacts.append(hit)
	_update_damage_number(hit)


func _flash_and_recoil(fighter: Fighter, target: Vector2, strength: float, defeated: bool) -> void:
	var sprite := fighter.character_sprite
	var flash := Sprite2D.new()
	flash.texture = sprite.texture
	flash.centered = sprite.centered
	flash.offset = sprite.offset
	flash.flip_h = sprite.flip_h
	flash.flip_v = sprite.flip_v
	var material := ShaderMaterial.new()
	material.shader = flash_shader
	flash.material = material
	flash.self_modulate.a = minf(1.0, tuning.impact_flash_opacity * (1.4 if defeated else 1.0))
	sprite.add_child(flash)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "self_modulate:a", 0.0, tuning.impact_flash_seconds)
	flash_tween.tween_callback(flash.queue_free)

	var source := Vector2.ZERO
	for origin in origins:
		source += origin
	source /= maxi(1, origins.size())
	var direction := (target - source).normalized()
	var world_offset := direction * minf(18.0, tuning.recoil_distance * strength)
	var position := sprite.position
	var displaced := position + fighter.to_local(target + world_offset) - fighter.to_local(target)
	var recoil := fighter.create_tween()
	recoil.tween_property(sprite, "position", displaced, 0.037).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	recoil.tween_property(sprite, "position", position, tuning.recoil_return_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _find_number_origin(at: Vector2, size: Vector2) -> Vector2:
	var best := at
	var best_cost := INF
	for dx in [0.0, -36.0, 36.0, -72.0, 72.0]:
		for dy in [0.0, 26.0]:
			var origin := Vector2(clampf(at.x + dx, size.x * 0.6 + 8.0, get_viewport_rect().size.x - size.x * 0.6 - 8.0), at.y + dy)
			var area := Rect2(origin - Vector2(size.x * 0.6, 20.0 + size.y * 0.1), Vector2(size.x * 1.2, size.y * 1.2 + 20.0))
			var cost: float = absf(dx) + dy
			for hit in impacts:
				var current := Rect2(hit.label.position, hit.label.size).grow(8.0)
				cost += area.intersection(current).get_area()
			if cost < best_cost:
				best_cost = cost
				best = origin
	return best


func _update_damage_number(hit: Impact) -> void:
	var rise := clampf((hit.age - 0.09) / (tuning.damage_hold_seconds + tuning.damage_fade_seconds), 0.0, 1.0)
	var pop := lerpf(0.7, 1.2, clampf(hit.age / 0.065, 0.0, 1.0))
	if hit.age > 0.065:
		pop = lerpf(1.2, 1.0, clampf((hit.age - 0.065) / 0.09, 0.0, 1.0))
	hit.label.scale = Vector2.ONE * pop
	hit.label.position = hit.number_origin - Vector2(hit.label.size.x * 0.5, hit.label.size.y * 0.5 + rise * 23.0)
	hit.label.modulate.a = 1.0 - clampf((hit.age - tuning.damage_hold_seconds) / tuning.damage_fade_seconds, 0.0, 1.0)


func finish_shots() -> void:
	origins.clear()
	volley_targets.clear()
	volley_strengths.clear()
	firing_balls.clear()
	shot_duration = 0.0
	queue_redraw()


func _prune_balls() -> void:
	for index in range(participants.size() - 1, -1, -1):
		var ball := participants[index]
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			participants.remove_at(index)


func _process(delta: float) -> void:
	_prune_balls()
	for index in range(impacts.size() - 1, -1, -1):
		var hit := impacts[index]
		hit.age += delta
		if hit.age >= tuning.damage_hold_seconds + tuning.damage_fade_seconds:
			hit.label.queue_free()
			impacts.remove_at(index)
		else:
			_update_damage_number(hit)
	queue_redraw()


func _draw() -> void:
	for ball in participants + firing_balls:
		if is_instance_valid(ball) and not ball.is_queued_for_deletion():
			var center := to_local(ball.global_position)
			var radius: float = ball.ball_data.get_radius() + 3.0
			var glow := 0.52 if shot_duration > 0.0 else 0.30
			draw_arc(center, radius + 2.0, 0.0, TAU, 42, Color(0.35, 0.95, 1.0, glow), 7.0, true)
			draw_arc(center, radius, 0.0, TAU, 42, Color("#abf7ff"), 2.0, true)
	for hit in impacts:
		_draw_impact(hit)
	if shot_duration <= 0.0:
		return
	var progress := clampf(float(Time.get_ticks_msec() - shot_start_msec) / 1000.0 / shot_duration, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.45, 1.0, progress)
	var travel := minf(progress / TRAVEL_FRACTION, 1.0)
	if spread_volley:
		var center := Vector2.ZERO
		for origin in origins:
			center += origin
		center /= maxi(1, origins.size())
		var junction := to_local(Vector2(center.x, clampf(center.y - 90.0, 445.0, 675.0)))
		for origin in origins:
			var start := to_local(origin)
			_draw_beam(start, start.lerp(junction, minf(travel * 2.0, 1.0)), intensity, alpha)
		if travel >= 0.5:
			draw_circle(junction, 7.0 * intensity, Color(0.86, 1.0, 1.0, alpha), true, -1.0, true)
			for index in range(volley_targets.size()):
				var endpoint := to_local(volley_targets[index])
				_draw_beam(junction, junction.lerp(endpoint, travel * 2.0 - 1.0), volley_strengths[index], alpha)
		return
	var endpoint := to_local(volley_targets[0])
	for origin in origins:
		var start := to_local(origin)
		draw_circle(start, 7.0 + intensity * 5.0, Color(0.48, 0.95, 1.0, alpha * 0.55), true, -1.0, true)
		_draw_beam(start, start.lerp(endpoint, travel), intensity, alpha)


func _draw_beam(start: Vector2, tip: Vector2, strength: float, alpha: float) -> void:
	draw_line(start, tip, Color(0.28, 0.83, 1.0, alpha * 0.38), 14.0 * strength, true)
	draw_line(start, tip, Color(0.92, 1.0, 1.0, alpha), 4.0 * strength, true)


func _draw_impact(hit: Impact) -> void:
	var progress := clampf(hit.age / tuning.impact_ring_seconds, 0.0, 1.0)
	if progress >= 1.0:
		return
	var strength := hit.strength * (1.23 if hit.defeated else 1.0)
	var alpha := 1.0 - progress
	var radius := lerpf(7.0, minf(55.0, tuning.impact_ring_radius * strength), ease(progress, 0.48))
	draw_circle(hit.position, 9.0 * strength, Color(0.83, 0.98, 1.0, alpha * alpha * 0.76), true, -1.0, true)
	draw_arc(hit.position, radius, 0.0, TAU, 36, Color(0.75, 0.96, 1.0, alpha), 3.2 * strength, true)
	var count := clampi(roundi(tuning.impact_particle_count * strength), 3, 16)
	for index in range(count):
		var angle := TAU * index / count + 0.34
		var spread := (23.0 + float(index % 3) * 9.0) * strength
		var point := hit.position + Vector2.from_angle(angle) * (8.0 + ease(progress, 0.65) * spread)
		var size := tuning.impact_particle_size * minf(strength, 1.5) * alpha
		draw_circle(point, size, Color(0.66, 0.97, 1.0, alpha), true, -1.0, true)
