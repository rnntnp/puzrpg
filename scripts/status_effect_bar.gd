class_name StatusEffectBar
extends HBoxContainer

const IndicatorScene = preload("res://scenes/status_effect_indicator.tscn")

var indicators: Dictionary = {}


func set_effect(data: StatusEffectData, remaining_turns: int) -> void:
	if data == null or data.effect_id.is_empty():
		return
	var indicator: StatusEffectIndicator = indicators.get(data.effect_id)
	var was_created := false
	if not is_instance_valid(indicator):
		indicator = IndicatorScene.instantiate() as StatusEffectIndicator
		add_child(indicator)
		indicators[data.effect_id] = indicator
		was_created = true
	indicator.set_effect(data, remaining_turns)
	if was_created and data.play_apply_pop:
		indicator.play_apply_pop()


func remove_effect(effect_id: StringName) -> void:
	var indicator: StatusEffectIndicator = indicators.get(effect_id)
	if not is_instance_valid(indicator):
		return
	indicators.erase(effect_id)
	indicator.queue_free()


func dismiss_effect_with_shake(effect_id: StringName) -> void:
	var indicator: StatusEffectIndicator = indicators.get(effect_id)
	if not is_instance_valid(indicator):
		return
	indicators.erase(effect_id)
	await indicator.play_interrupted_and_free()


func clear_effects() -> void:
	for indicator in indicators.values():
		if is_instance_valid(indicator):
			indicator.queue_free()
	indicators.clear()
