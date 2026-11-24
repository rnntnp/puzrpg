extends Resource

enum Card { STONE, HEAL, SATELLITE, EVOLUTION_1, EVOLUTION_2, EVOLUTION_3,
	LIGHTNING, SHOTGUN, COMBO_2, COMBO_3, COMBO_4, BUILDUP, RESOLVE, CLEANUP, REVENGE_1, REVENGE_2, SACRIFICE }

const NAMES := ["돌가죽", "생명 흡수", "위성 방울", "진화 I", "진화 II", "진화 III",
	"번개", "샷건 강화", "연쇄 합성", "삼중 합성", "사중 합성", "축적", "불굴", "대청소", "복수 I", "복수 II", "희생"]
const ICONS := ["◆", "♥", "◉", "↑", "↑", "↑", "⚡", "✦", "×", "×", "×", "＋", "♥", "◇", "↶", "↶", "◆"]
const PREREQUISITES := {Card.EVOLUTION_2: Card.EVOLUTION_1, Card.EVOLUTION_3: Card.EVOLUTION_2,
	Card.COMBO_3: Card.COMBO_2, Card.COMBO_4: Card.COMBO_3, Card.REVENGE_2: Card.REVENGE_1,
	Card.SACRIFICE: Card.RESOLVE}

@export var damage_reduction := 2
@export var heal_per_merge := 1
@export_range(0.0, 1.0, 0.01) var satellite_launch_delay := 0.12
@export var lightning_hit_interval := 3
@export var lightning_damage := 18
@export var shotgun_multiplier := 1.5
@export var combo_bonuses := Vector3(0.25, 0.50, 0.80)
@export var buildup_bonus := 0.15
@export var max_stacks := 4
@export var resolve_threshold := 0.30
@export var resolve_bonus := 0.30
@export_range(1, 99, 1) var sacrifice_hp := 5
@export_range(0.05, 1.0, 0.05) var sacrifice_bonus := 0.20
@export var cleanup_threshold := 0.50
@export var cleanup_count := 3
@export var revenge_damage := 5
@export var drop_window_size := 5


func card_description(card: int, _rank: int) -> String:
	match card:
		Card.STONE: return "적에게 받는 피해가 %d 감소합니다." % damage_reduction
		Card.HEAL: return "방울을 합성할 때마다 HP를 %d 회복합니다." % heal_per_merge
		Card.SATELLITE: return "투하할 때마다 투하 가능한 가장 낮은 단계의 방울을 하나 더 발사합니다."
		Card.EVOLUTION_1, Card.EVOLUTION_2, Card.EVOLUTION_3:
			var removed := card - Card.EVOLUTION_1 + 1
			return "%d단계 이하 방울을 제거하고, 이후 %d~%d단계 방울을 투하합니다." % [removed, removed + 1, removed + drop_window_size]
		Card.LIGHTNING: return "합성 공격 %d회마다 번개 피해 %d을 입힙니다." % [lightning_hit_interval, lightning_damage]
		Card.SHOTGUN: return "적 처치 시 발생하는 샷건 피해가 %s배가 됩니다." % str(shotgun_multiplier)
		Card.COMBO_2, Card.COMBO_3, Card.COMBO_4:
			var index := card - Card.COMBO_2
			return "한 턴 내 %d번째 합성부터 공격 피해가 %d%% 증가합니다." % [index + 2, roundi(combo_bonuses[index] * 100)]
		Card.BUILDUP: return "미합성 턴마다 다음 합성 공격 피해 +%d%%. 최대 +%d%%." % [roundi(buildup_bonus * 100), roundi(buildup_bonus * max_stacks * 100)]
		Card.RESOLVE: return "HP가 %d%% 이하일 때 합성 공격 피해 +%d%%." % [roundi(resolve_threshold * 100), roundi(resolve_bonus * 100)]
		Card.CLEANUP: return "수조에서 가장 큰 방울 %d개를 제거합니다." % cleanup_count
		Card.REVENGE_1: return "적에게 피해를 입으면 공격한 적에게 피해 %d을 입힙니다." % revenge_damage
		Card.REVENGE_2: return "적에게 피해를 입으면 모든 적에게 피해 %d을 입힙니다." % revenge_damage
		Card.SACRIFICE: return "웨이브당 1회 HP %d를 지불해 다음 합성 공격 피해를 %d%% 높입니다." % [sacrifice_hp, roundi(sacrifice_bonus * 100.0)]
	return ""


func offer(owned: Array[int], saturation: float) -> Array[int]:
	var base: Array[int] = []
	var advanced: Array[int] = []
	var offered: Array[int] = []
	for card in range(NAMES.size()):
		if owned.has(card) or (card == Card.CLEANUP and saturation < cleanup_threshold):
			continue
		if not PREREQUISITES.has(card):
			base.append(card)
		elif owned.has(PREREQUISITES[card]):
			advanced.append(card)
	base.shuffle()
	advanced.shuffle()
	if not advanced.is_empty():
		offered.append(advanced.pop_back())
	while offered.size() < 3 and not base.is_empty():
		offered.append(base.pop_back())
	while offered.size() < 3 and not advanced.is_empty():
		offered.append(advanced.pop_back())
	return offered
