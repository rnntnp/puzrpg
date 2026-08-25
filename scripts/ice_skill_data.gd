class_name IceSkillData
extends Resource

@export_category("빙결 대상")
@export_range(1, 3, 1) var freeze_count: int = 1
@export_range(1, 11, 1) var target_min_level: int = 1
@export_range(1, 11, 1) var target_max_level: int = 3
## 첫 우선순위 대상 주변에서 단계와 관계없이 추가로 찾을 얼지 않은 공 수다.
@export_range(0, 2, 1) var nearby_unfrozen_count: int = 0

@export_category("행동 주기")
## 일반 공격이 끝난 뒤 다음 빙결 스킬까지 필요한 완료 턴 수다.
@export_range(1, 20, 1) var ice_action_interval: int = 3
## 참이면 첫 행동이 빙결이고, 거짓이면 첫 행동이 일반 공격이다.
@export var starts_with_ice_action: bool = true

@export_category("군집 빙결")
## 0이면 우선순위 대상을 그대로 쓰며, 양수면 이 수만큼의 얼지 않은 우선 후보를 섞어 대상을 고른다.
@export_range(0, 11, 1) var random_primary_candidate_count: int = 0
@export_category("얼음")
@export_range(1, 9, 1) var ice_durability: int = 2
@export_range(0.0, 2.0, 0.05) var target_highlight_duration: float = 0.25
@export_range(0.0, 2.0, 0.05) var freeze_effect_duration: float = 0.3

@export_category("공격")
@export var deals_direct_damage: bool = true

@export_category("대상 없음")
@export_range(1.0, 3.0, 0.05) var no_target_damage_multiplier: float = 1.5
