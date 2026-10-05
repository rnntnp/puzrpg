extends Resource

@export_category("던전 웨이브")
@export var wave_names: PackedStringArray = ["입구의 파수꾼", "동굴의 무리", "수정 갑옷 정예", "심층의 사냥꾼", "수정 던전 군주"]
@export var wave_damage: Array[int] = [4, 5, 7, 7, 10]
@export var wave_intervals: Array[int] = [4, 3, 4, 2, 3]
@export_range(0.1, 1.0, 0.05) var armor_multiplier := 0.65
@export_range(2, 5, 1) var armor_bypass_chain := 2
@export_range(1.0, 3.0, 0.1) var boss_enrage_multiplier := 1.5
@export_range(0.1, 0.9, 0.05) var boss_enrage_health_ratio := 0.5

@export_category("카드 · 등급당 누적 효과")
@export_range(1, 5, 1) var maximum_rank := 3
@export_range(0.05, 1.0, 0.05) var attack_per_rank := 0.25
@export_range(0.05, 0.3, 0.05) var critical_chance_per_rank := 0.20
@export_range(1.1, 4.0, 0.1) var critical_multiplier := 2.0
@export_range(1, 10, 1) var lightning_hit_interval := 3
@export_range(1, 100, 1) var lightning_damage_per_rank := 18
@export_range(0.05, 1.0, 0.05) var ricochet_per_rank := 0.30
@export_range(1, 10, 1) var healing_per_rank := 1
@export_range(1, 10, 1) var guard_per_rank := 2

const CARD_NAMES := ["강타", "치명타", "번개", "도탄", "생명 흡수", "돌가죽"]
const CARD_COLORS := [Color("ffba70"), Color("ff7ca5"), Color("86ddff"), Color("d1a0ff"), Color("80e4b1"), Color("acbddb")]

func card_description(card: int, rank: int) -> String:
	match card:
		0: return "모든 합성 공격 피해 +%d%%" % roundi(attack_per_rank * rank * 100.0)
		1: return "합성 공격 %d%% 확률로 ×%.1f 피해" % [roundi(minf(1.0, critical_chance_per_rank * rank) * 100.0), critical_multiplier]
		2: return "합성 공격 %d회 적중마다 번개 +%d 피해" % [lightning_hit_interval, lightning_damage_per_rank * rank]
		3: return "합성 공격이 되튕겨 같은 적에게 +%d%% 피해" % roundi(ricochet_per_rank * rank * 100.0)
		4: return "합성 공격 적중마다 체력 %d 회복" % (healing_per_rank * rank)
		5: return "적의 반격 피해 %d 감소 (넘침 피해 제외)" % (guard_per_rank * rank)
	return ""
