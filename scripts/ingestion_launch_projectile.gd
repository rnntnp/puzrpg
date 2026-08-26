class_name IngestionLaunchProjectile
extends Node2D

signal crossed_player
signal flight_finished

var _sprite := Sprite2D.new()


func _ready() -> void:
	z_index = 250
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)


func play(from_global: Vector2, player_global_x: float, data: BallData, duration := 0.34) -> void:
	global_position = from_global
	_sprite.texture = data.sprite
	_sprite.modulate = data.sprite_modulate
	var texture_size := _sprite.texture.get_size() if _sprite.texture != null else Vector2.ONE
	var diameter := clampf(data.get_radius() * 2.0, 44.0, 120.0)
	_sprite.scale = Vector2(diameter / texture_size.x, diameter / texture_size.y)

	var exit_x := -diameter
	var travel_distance := maxf(global_position.x - exit_x, 1.0)
	var crossing_ratio := clampf((global_position.x - player_global_x) / travel_distance, 0.05, 0.95)

	var crossing_tween := create_tween()
	crossing_tween.tween_interval(duration * crossing_ratio)
	crossing_tween.tween_callback(crossed_player.emit)

	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_LINEAR)
	flight.tween_property(self, "global_position:x", exit_x, duration)
	flight.tween_property(_sprite, "rotation", -TAU * 1.8, duration)
	await flight.finished
	flight_finished.emit()
	queue_free()
