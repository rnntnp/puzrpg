class_name LevelData
extends Resource

const CharacterDataClass = preload("res://scripts/character_data.gd")
const TestGimmickDataClass = preload("res://scripts/test_gimmick_data.gd")

@export_category("레벨 정보")
@export var level_name: String = "Level"
@export_multiline var image_placeholder: String = "LEVEL IMAGE\nPLACEHOLDER"
@export var battle_background: Texture2D
@export_group("세로 확장 배경")
@export var battle_background_top: Texture2D
@export var battle_background_middle: Texture2D
@export var battle_background_bottom: Texture2D
@export var battle_music: AudioStream
## 720px 기준 상단 고정 레이어의 표시 높이다.
@export_range(100.0, 900.0, 1.0) var battle_background_top_height: float = 508.0
@export_group("")
@export var level_select_preview: Texture2D

@export_category("전투 UI")
@export var show_battle_status_label := true
@export var show_gimmick_status_labels := true

@export_category("레벨 선택 정보")
@export_range(1, 11, 1) var recommended_ball_level: int = 5
@export var stage_gimmick_icon: Texture2D
@export var stage_gimmick_name: String = "기본 전투"
@export var reward_name: String = "첫 승리 보상"
@export_range(0, 99999, 1) var clear_gold_reward: int = 150

@export_category("전투 구성")
@export var player_character: CharacterDataClass
@export var enemies: Array[CharacterDataClass] = []

@export_category("시작 연출")
## 첫 항목은 자동으로 페이드 인/아웃되며, 이후 항목은 클릭 또는 확인 키로 넘긴다.
@export var opening_sequence: PackedStringArray = []
## 로고 다음 페이지부터 순서대로 표시할 스토리 이미지다. 비어 있으면 기존 텍스트를 표시한다.
@export var opening_story_images: Array[Texture2D] = []
## 스토리 컷씬이 끝나고 전투 화면 위에서 표시하는 조작 안내다.
@export var tutorial_sequence: PackedStringArray = []
## 첫 드롭의 턴 처리 뒤에 표시하는 안내 문구다.
@export_multiline var tutorial_turn_message: String = ""
## 적 공격을 본 뒤, 방울 진화표와 함께 표시하는 안내다.
@export var tutorial_evolution_messages: PackedStringArray = []
## 첫 실제 포식이 완료된 뒤 보호막 대응 안내를 한 번 표시한다.
@export var ingestion_tutorial_enabled := false
## 0은 표시 단계 1이다. 음수면 기존 랜덤 드롭 풀을 사용한다.
@export_range(-1, 10, 1) var fixed_drop_level: int = -1

@export_category("기믹 테스트")
@export var is_gimmick_test_level := false
@export var test_gimmick: TestGimmickDataClass

@export_category("드롭 앤 머지 설정")
## 음수로 설정하면 자동 낙하와 시간제한을 사용하지 않는다.
@export var ball_drop_time_limit: float = 5.0
@export_range(1, 11, 1) var max_ball_level: int = 11
## 1.0은 물리 기준 속도이며, 현재 전체 레벨 기본 낙하 배속은 1.2다.
@export_range(0.5, 3.0, 0.1) var ball_physics_speed: float = 1.2
## 합성 지점에서 주변 공으로 퍼지는 짧은 충격파의 세기다. 0이면 비활성화한다.
@export_range(0.0, 500.0, 5.0) var merge_push_force: float = 110.0
## 합성 순간의 전체 게임 배속. 1.0이면 슬로모션을 사용하지 않는다.
@export_range(0.05, 1.0, 0.05) var merge_hit_stop_time_scale: float = 0.25
## 슬로모션이 유지되는 실제 시간(초).
@export_range(0.0, 0.5, 0.01) var merge_hit_stop_duration: float = 0.12
## 연쇄 합성으로 생성된 공이 다음 합성을 시작하기 전의 실제 시간(초).
@export_range(0.0, 0.8, 0.01) var chain_merge_delay: float = 0.1

@export_category("진행")
@export_file("*.tres") var next_level_path: String
