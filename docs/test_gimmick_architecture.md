# 테스트 기믹 확장 구조

## 목표

신규 테스트 기믹이 `Battle`, `MonsterActionController`, `MergeGame`의 종류별 분기를 늘리지 않도록 한다.
레벨별 밸런스 값은 전용 `Resource`에 두고 Inspector에서 현재 기믹과 관계없는 값이 섞이지 않게 한다.

## 런타임 흐름

1. `LevelData.test_gimmick`이 `TestGimmickData`를 제공한다.
2. `TestGimmickController`는 `handler_script`를 인스턴스화한다.
3. 핸들러는 `TestGimmickHandler`를 상속하고 턴, 합성, 피해, 물리 이벤트 중 필요한 것만 구현한다.
4. `handler_script`가 없는 기존 레벨은 `LegacyTestGimmickHandler`로 실행된다.

`LegacyTestGimmickHandler`는 기존 프로토타입의 호환 계층이다. 신규 기믹을 이 파일에 추가하지 않는다.
모듈 핸들러는 `Kind` 분기에 의존하지 않으므로 신규 기믹 때문에 기존 enum이나 중앙 `match`를 확장할 필요가 없다.

## 신규 기믹 추가 순서

1. `scripts/gimmicks/configs/`에 기믹 전용 설정 Resource를 만든다.
2. `scripts/gimmicks/handlers/`에 `TestGimmickHandler` 상속 스크립트를 만든다.
3. 전용 보드 표시가 필요하면 `scripts/gimmicks/visuals/`에 독립 `Node2D`를 만들고 `attach_visual_layer()`로 연결한다.
4. 테스트 레벨의 `TestGimmickData`에 `handler_script`와 `tuning`을 지정한다.
5. 복수 몬스터라면 `enemy_healths`와 `preserve_board_between_enemies`를 설정한다.
6. `resources/catalogs/main_level_catalog.tres`의 `test_level_paths`에 레벨을 등록한다.

기믹 종류별 HP나 보드 유지 조건을 `Battle` 또는 `MonsterActionController`에 추가하지 않는다.

## 핸들러 수명주기

- `_on_configured()`: 초기 상태, UI, 임시 노드 생성
- `on_turn_completed()`: 정상 투하와 합성이 끝난 뒤의 턴 처리
- `modify_player_damage()`: 합성 피해 보정
- `_physics_process_gimmick()`: 매 물리 프레임 처리가 필요한 경우
- `_on_merge_registered()`: 정상 합성 등록 이벤트
- `_on_merge_completed()`: 결과 공 생성 완료 이벤트
- `_on_player_ball_landed()`: 투하 공 최초 착지 이벤트
- `_on_cleanup()`: 핸들러 전용 상태 정리

기반 클래스가 시그널 연결, Tween 종료, MergeGame 기믹 상태 초기화, Intent UI 제거를 담당한다.
`attach_visual_layer()`로 추가한 전용 Overlay도 기반 클래스가 제거한다. 신규 시각화를 공용 `gimmick_overlay.gd`의 `_draw()` 분기에 계속 추가하지 않는다.

## 데이터 배치

공통 필드:

- 몬스터 공격력과 행동 간격
- `enemy_healths`
- `preserve_board_between_enemies`
- `handler_script`
- `tuning`

기믹별 수치는 전용 `tuning` Resource에 둔다. `TestGimmickData`에 신규 전용 export 필드를 계속 추가하지 않는다.

## 레벨 등록

캠페인과 테스트 레벨 목록은 `resources/catalogs/main_level_catalog.tres`에서 관리한다.
`GameSession`이나 테스트 도구에 별도의 경로 배열을 만들지 않는다.
