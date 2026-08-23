# 39. 유리 상승 / 파괴 지형

## 공통 규칙

- 유리 하중은 해당 유리에 실제로 지지된 공과 그 위로 접촉해 쌓인 공의 표시 Stage 합이다. 공의 Physics Mass는 사용하지 않는다.
- 플레이어 투하 뒤의 정상 합성 및 연쇄합성이 정리된 후에만 하중과 파괴를 판정한다. 합성 직전의 일시적 하중으로 유리가 먼저 깨지지 않는다.
- 하중이 내려가도 Cracked 외형은 Normal로 복구되지 않는다. 파괴 여부는 현재 하중으로 계속 판정한다.
- Destroyed 유리는 Collision만 제거한다. 공은 자연 낙하하며, 이후 합성은 기존 Merge 시스템을 그대로 사용한다.
- 유리 이동 중에는 지지 공도 함께 이동하고, 입력과 Danger Line 판정은 기존 보호 구간으로 잠시 막는다.

## Enemy 1 — Central Glass Rise

- 5 player drops마다 하나의 중앙 유리를 `없음 → C1 → C2 → C3`으로만 생성·상승시킨다. 동시에 존재하는 유리는 최대 하나이며, 아래 유리를 보충하지 않는다.
- C3에 도달한 뒤에는 3 player drops마다 일반 공격(피해 5)을 사용한다. 유리가 파괴되어 없어지면 다시 5턴 Glass Rise로 돌아간다.
- 폭은 playable board width의 55%, 높이는 실제 투하선부터 바닥까지의 playable board 기준 C3 30% / C2 50% / C1 70%다.
- 균열/파괴 하중은 10 / 16이다.
- Enemy 1 처치 시 남아 있는 중앙 유리는 Collision만 해제되어 공이 자연 낙하한다. 공과 보드는 초기화하지 않고 Enemy 2로 전환한다.

## Enemy 2 — Twin Glass Rise

- 중앙 유리는 사용하지 않는다. LEFT와 RIGHT는 각각 `없음 → lower → upper` 유리 하나만 독립적으로 관리한다. 동시에 존재 가능한 유리는 최대 둘이다.
- 5 player drops마다 각 side를 판정한다. 유리가 없으면 lower를 만들고, lower에 있으면 upper로 올리며, upper에 있으면 그대로 유지한다. 상승 뒤 lower를 다시 만들지 않는다.
- L2와 R2가 모두 존재하면 3 player drops마다 일반 공격(피해 5)을 사용한다. 한쪽 유리가 파괴되어 다시 상승 가능해지면 5턴 Side Glass Rise로 돌아간다.
- 유리 폭은 각각 playable board width의 34%, 좌우 외곽 여백은 11%, 중앙 간격은 10%다. lower/upper 높이는 72% / 50%다.
- 균열/파괴 하중은 9 / 14다.

## Enemy 3

Enemy 3의 기존 중앙 적층·빈 슬롯 보충 규칙은 이 변경에서 수정하지 않는다.

## 조절값

`resources/levels/test_weight_break_terrain.tres`의 `WeightBreakTerrainConfig`에서 행동 간격, 각 phase의 폭·내구도, 슬롯 높이, 이동 시간 및 하중 접촉 오차를 조절한다.

## 플레이테스트 확인

- Enemy 1의 55% 중앙 유리에서 Stage 3~5 공을 쌓고 합성할 공간이 충분한가?
- Enemy 1의 C2/C3 상승이 Danger Line 압박으로 읽히는가?
- Enemy 2의 34% 좌우 유리에서 Stage 3~4 공을 두 개 이상 다루는 것이 가능한가?
- 합성으로 하중을 줄여 유리를 보존하거나, 의도적으로 하중을 쌓아 유리를 깨뜨리는 선택이 보이는가?
