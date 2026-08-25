class_name StatusEffectData
extends Resource

@export var effect_id: StringName
@export var display_name: String = "Effect"
@export var icon: Texture2D
@export var icon_modulate: Color = Color.WHITE
@export_range(1.0, 5.0, 0.05) var incoming_damage_multiplier: float = 1.0
