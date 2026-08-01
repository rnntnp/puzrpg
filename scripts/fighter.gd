class_name Fighter
extends Polygon2D

const CharacterDataClass = preload("res://scripts/character_data.gd")

signal health_changed(current_health: int, max_health: int)
signal defeated(fighter: Fighter)

@export var character_data: CharacterDataClass

var current_health: int
var cooldown_remaining := 0.0

var max_health: int:
	get: return character_data.max_health
var attack_power: int:
	get: return character_data.attack_power
var attack_cooldown: float:
	get: return character_data.attack_cooldown
var display_name: String:
	get: return character_data.display_name


func _ready() -> void:
	assert(character_data != null, "%s에 CharacterData가 지정되지 않았습니다." % name)
	color = character_data.display_color
	reset()


func reset() -> void:
	current_health = max_health
	cooldown_remaining = attack_cooldown
	modulate = Color.WHITE
	health_changed.emit(current_health, max_health)


func advance_cooldown(delta: float) -> bool:
	if not is_alive():
		return false
	cooldown_remaining -= delta
	if cooldown_remaining > 0.0:
		return false
	cooldown_remaining += attack_cooldown
	return true


func attack(target: Fighter) -> void:
	if not is_alive() or not target.is_alive():
		return
	target.take_damage(attack_power)
	play_attack_animation(target)


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	current_health = max(0, current_health - max(0, amount))
	health_changed.emit(current_health, max_health)
	play_hit_animation()
	if current_health == 0:
		modulate = Color("#556070")
		defeated.emit(self)


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
