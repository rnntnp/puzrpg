class_name StatusEffectIndicator
extends Control

@onready var icon_rect: TextureRect = $Icon
@onready var turn_label: Label = $TurnLabel

var effect_data: StatusEffectData
var _visual_tween: Tween


func set_effect(data: StatusEffectData, remaining_turns: int) -> void:
	effect_data = data
	icon_rect.texture = data.icon
	icon_rect.modulate = data.icon_modulate
	tooltip_text = data.display_name
	turn_label.visible = data.show_turns
	set_remaining_turns(remaining_turns)


func set_remaining_turns(remaining_turns: int) -> void:
	turn_label.text = str(maxi(0, remaining_turns))


func play_apply_pop() -> void:
	if is_instance_valid(_visual_tween):
		_visual_tween.kill()
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2.ONE * 0.72
	modulate.a = 0.0
	_visual_tween = create_tween()
	_visual_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(self, "scale", Vector2.ONE * 1.16, 0.18)
	_visual_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.10)
	_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_visual_tween.tween_property(self, "scale", Vector2.ONE, 0.14)


func play_interrupted_and_free() -> void:
	if is_instance_valid(_visual_tween):
		_visual_tween.kill()
	scale = Vector2.ONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_x := position.x
	var tween := create_tween()
	for offset in [8.0, -8.0, 7.0, -7.0, 4.0, -4.0]:
		tween.tween_property(self, "position:x", start_x + offset, 0.055)
	tween.tween_property(self, "position:x", start_x, 0.04)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	await tween.finished
	queue_free()
