class_name StatusEffectBar
extends HBoxContainer

const IndicatorScene = preload("res://scenes/status_effect_indicator.tscn")

var indicators: Dictionary = {}


func set_effect(data: StatusEffectData, remaining_turns: int) -> void:
	if data == null or data.effect_id.is_empty():
		return
	var indicator: StatusEffectIndicator = indicators.get(data.effect_id)
	if not is_instance_valid(indicator):
		indicator = IndicatorScene.instantiate() as StatusEffectIndicator
		add_child(indicator)
		indicators[data.effect_id] = indicator
	indicator.set_effect(data, remaining_turns)


func remove_effect(effect_id: StringName) -> void:
	var indicator: StatusEffectIndicator = indicators.get(effect_id)
	if not is_instance_valid(indicator):
		return
	indicators.erase(effect_id)
	indicator.queue_free()


func clear_effects() -> void:
	for indicator in indicators.values():
		if is_instance_valid(indicator):
			indicator.queue_free()
	indicators.clear()
