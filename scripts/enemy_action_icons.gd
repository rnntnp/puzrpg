extends RefCounted

enum Kind { ATTACK, SKILL, HEAL, UNKNOWN }

const ATTACK_ICON = preload("res://assets/effects/generated/status_attack.png")
const LABELS := ["일반 공격", "스킬", "회복", "불명"]
const SYMBOLS := {
	Kind.HEAL: ["#6DE698", '<path d="M24 9H40V24H55V40H40V55H24V40H9V24H24Z"/>'],
	Kind.SKILL: ["#F6C969", '<path d="M32 5 39 24 59 32 39 40 32 59 25 40 5 32 25 24Z"/>'],
	Kind.UNKNOWN: ["#E3E5EB", '<path d="M20 20Q21 9 32 9Q45 9 45 21Q45 28 36 32Q31 35 31 41" fill="none" stroke="currentColor" stroke-width="8" stroke-linecap="round"/><circle cx="31" cy="54" r="4.5"/>'],
}

static var textures: Dictionary[int, Texture2D] = {}
static var intent_effects: Dictionary[Vector2i, StatusEffectData] = {}


static func skill_intent(effect: StatusEffectData, boss: bool, witnessed: bool, generic_kind := Kind.SKILL) -> StatusEffectData:
	if effect.use_authored_intent_icon:
		return effect
	if boss and witnessed:
		return effect
	var kind: int = Kind.UNKNOWN if boss else generic_kind
	var key := Vector2i(effect.get_instance_id(), kind)
	if not intent_effects.has(key):
		var display := effect.duplicate() as StatusEffectData
		display.icon = texture_for(kind)
		display.display_name = label_for(kind) + "까지 남은 턴"
		intent_effects[key] = display
	return intent_effects[key]


static func label_for(kind: int) -> String:
	return LABELS[kind] if kind >= 0 and kind < LABELS.size() else "행동 정보 없음"


static func texture_for(kind: int) -> Texture2D:
	if kind == Kind.ATTACK:
		return ATTACK_ICON
	if not SYMBOLS.has(kind):
		push_warning("Invalid enemy action icon kind: %d" % kind)
		return null
	if not textures.has(kind):
		var symbol: Array = SYMBOLS[kind]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="%s">%s</svg>' % [symbol[0], symbol[1].replace("currentColor", symbol[0])]
		var artwork := Image.new()
		if artwork.load_svg_from_string(svg) == OK:
			textures[kind] = ImageTexture.create_from_image(artwork)
		else:
			push_warning("Could not load enemy action icon kind: %d" % kind)
	return textures.get(kind)
