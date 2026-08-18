class_name LevelData
extends Resource

const CharacterDataClass = preload("res://scripts/character_data.gd")
const TestGimmickDataClass = preload("res://scripts/test_gimmick_data.gd")

@export_category("레벨 정보")
@export var level_name: String = "Level"
@export_multiline var image_placeholder: String = "LEVEL IMAGE\nPLACEHOLDER"
@export var battle_background: Texture2D
@export var level_select_preview: Texture2D

@export_category("레벨 선택 정보")
@export_range(1, 11, 1) var recommended_ball_level: int = 5
@export var stage_gimmick_icon: Texture2D
@export var stage_gimmick_name: String = "기본 전투"
@export var reward_name: String = "첫 승리 보상"

@export_category("전투 구성")
@export var player_character: CharacterDataClass
@export var enemies: Array[CharacterDataClass] = []

@export_category("기믹 테스트")
@export var is_gimmick_test_level := false
@export var test_gimmick: TestGimmickDataClass

@export_category("드롭 앤 머지 설정")
## 음수로 설정하면 자동 낙하와 시간제한을 사용하지 않는다.
@export var ball_drop_time_limit: float = 5.0
@export_range(1, 11, 1) var max_ball_level: int = 11
## 1.0은 기본 속도이며, 1.6은 낙하 시간이 대략 1.6배 빨라진다.
@export_range(0.5, 3.0, 0.1) var ball_physics_speed: float = 1.6
## 공이 합쳐질 때 주변 공을 밀어내는 속도 변화량이다. 0이면 밀어내지 않는다.
@export_range(0.0, 500.0, 5.0) var merge_push_force: float = 90.0
## 합성 순간의 전체 게임 배속. 1.0이면 슬로모션을 사용하지 않는다.
@export_range(0.05, 1.0, 0.05) var merge_hit_stop_time_scale: float = 0.25
## 슬로모션이 유지되는 실제 시간(초).
@export_range(0.0, 0.5, 0.01) var merge_hit_stop_duration: float = 0.12
## 연쇄 합성으로 생성된 공이 다음 합성을 시작하기 전의 실제 시간(초).
@export_range(0.0, 0.8, 0.01) var chain_merge_delay: float = 0.1

@export_category("진행")
@export_file("*.tres") var next_level_path: String
