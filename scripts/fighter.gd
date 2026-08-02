class_name Fighter
extends Polygon2D

const CharacterDataClass = preload("res://scripts/character_data.gd")

signal health_changed(current_health: int, max_health: int)
signal defeated(fighter: Fighter)

@export var character_data: CharacterDataClass

var current_health: int
var base_scale: Vector2

var max_health: int:
	get: return character_data.max_health
var attack_power: int:
	get: return character_data.attack_power
var display_name: String:
	get: return character_data.display_name
var enemy_attack_drop_interval: int:
	get: return character_data.enemy_attack_drop_interval


func _ready() -> void:
	base_scale = scale
	assert(character_data != null, "%s에 CharacterData가 지정되지 않았습니다." % name)
	color = character_data.display_color
	reset()


func set_character_data(data: CharacterDataClass, refill_health := true) -> void:
	character_data = data
	color = character_data.display_color
	if refill_health:
		reset()


func reset() -> void:
	current_health = max_health
	visible = true
	scale = base_scale
	modulate = Color.WHITE
	health_changed.emit(current_health, max_health)


func attack(target: Fighter) -> void:
	attack_with_damage(target, attack_power)

func attack_with_damage(target: Fighter, damage: int) -> void:
	if not is_alive() or not target.is_alive():
		return
	target.take_damage(damage)
	play_attack_animation(target)


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	current_health = max(0, current_health - max(0, amount))
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		defeated.emit(self)
	else:
		play_hit_animation()


func is_alive() -> bool:
	return current_health > 0


func play_attack_animation(target: Fighter) -> void:
	var start_x := position.x
	var direction: float = signf(target.global_position.x - global_position.x)
	var tween := create_tween()
	tween.tween_property(self, "position:x", start_x + 45.0 * direction, 0.08)
	tween.tween_property(self, "position:x", start_x, 0.12)


func play_hit_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color("#ffdfdf"), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.16)

func play_defeat_animation() -> void:
	var defeated_scale := Vector2(base_scale.x * 1.15, 0.05)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", defeated_scale, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color(1.0, 0.35, 0.35, 0.0), 0.65)
	await tween.finished
	visible = false
