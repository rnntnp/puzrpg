class_name StatusEffectIndicator
extends Control

@onready var icon_rect: TextureRect = $Icon
@onready var turn_label: Label = $TurnLabel

var effect_data: StatusEffectData


func set_effect(data: StatusEffectData, remaining_turns: int) -> void:
	effect_data = data
	icon_rect.texture = data.icon
	icon_rect.modulate = data.icon_modulate
	tooltip_text = data.display_name
	turn_label.visible = data.show_turns
	set_remaining_turns(remaining_turns)


func set_remaining_turns(remaining_turns: int) -> void:
	turn_label.text = str(maxi(0, remaining_turns))
