# 커스텀 보드 물리 테스트

`0. 커스텀 물리 실험실`은 기존 1스테이지 앞에서 선택할 수 있는 비번호 개발 스테이지다.

- 기존 전투, 드롭, 합성, 콤보, 공격, 턴, 위험선 흐름은 그대로 사용한다.
- 공의 이동과 접촉만 `SuikaBoardSolver`가 고정 60Hz로 계산한다.
- 테스트 솔버는 모든 공을 질량 1의 수학적 원으로 취급한다.
- 각 공-공 및 공-바닥 접촉은 지속시간과 접촉 충격량을 별도로 기억한다.
- 오래 유지된 접촉은 마찰 한계가 서서히 낮아진다.
- 보드 운동에너지가 낮을 때 가장 눌린 접촉 하나가 기존 접촉 합력의 접선 방향으로 저장 압력을 방출한다.
- 방출 방향은 난수를 사용하지 않는다. 합력과 표면 상대속도에 방향 성분이 없으면 방출하지 않는다.
- 바닥에 고립된 공은 다른 공과 동시에 접촉하지 않으므로 jam slip 대상이 되지 않는다.
- slip이 선택된 접촉 하나만 짧은 시간 마찰이 0에 가까워지고, 나머지 보드 마찰은 유지된다.
- 다른 스테이지는 계속 Godot `RigidBody2D` 물리를 사용한다.
- 조절값은 `resources/custom_physics/test_board_physics.tres`에 있다.
- 레벨의 `custom_board_physics`를 비우면 기존 물리로 즉시 돌아간다.

이 스테이지는 물리 백엔드 비교용이며, 번호가 붙은 전투 기믹으로 등록하지 않는다.

## Jam Slip 주요 조절값

- `jam_minimum_contact_age`: 압력을 방출하기 전 필요한 최소 접촉 시간
- `jam_pressure_storage_ratio`: 접촉 충격량을 저장 압력으로 바꾸는 비율
- `jam_kinetic_energy_threshold`: 보드가 충분히 느릴 때만 방출하도록 하는 기준
- `jam_release_cooldown`: 서로 다른 접촉 사이를 포함한 전체 방출 최소 간격
- `jam_energy_to_impulse`, `jam_maximum_release_impulse`: 국소 slip의 이동 강도
- `jam_slip_duration`, `jam_slip_friction_multiplier`: 선택된 접촉만 잠시 풀리는 시간과 마찰
- `jam_friction_weakening_*`: 오래 jam된 접촉의 평상시 마찰 약화 속도
