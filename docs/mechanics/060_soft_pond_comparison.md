# 60번 XPBD / Quark 반복 비교 (2026-10-08)

## Latest: compare rendered outline deformation, not spring-length strain

Only resource parameters changed: native air damping 1.2→0.65/s, shape matching 0.12→0.8. Rigidity 0.4, area rigidity 1.0, 12 particles, 2 substeps and 4 iterations unchanged. No runtime code added. Diagnostic script lives in ignored tmp/quark_install/compare_deformation.gd.

Measure the same original sprite outline through the GPU's triangular deformation mapping, remove best-fit rigid translation/rotation, and divide maximum outline displacement by rest outline radius. This compares six-control XPBD with 12-particle Quark without assuming their different spring edge sets measure the same thing. It measures maximum local displacement, not area loss or uniform compression. Sample every 60Hz outer update for 3s. Unlike prior spring-strain tables, the current small ceiling ball had excess deformation while pair collisions had too little.

| Scenario | XPBD reference | Prior 12-point setting | Latest |
|---|---:|---:|---:|
| Small head-on pair, peak outline displacement | 12.3% | 6.7% | 10.3% |
| Small glancing pair | 6.5% | 4.6% | 8.1% |
| Stacked-ball impact | 18.2% | 20.2% | 17.6% |
| Small ceiling impact | 15.2% | 24.0% | 21.8% |
| Large ceiling impact | 13.3% | 11.3% | 8.5% |
| Free shape recovery, first-update peak | 4.6% | 0.8% | 0.8% |

Head-on time above half peak: XPBD 83ms / latest 67ms; stack 317ms / latest 333ms. Glancing deformation lasts longer than XPBD and large ceiling peak is farther from the reference. Small ceiling tail deformation still about 5.0% versus XPBD 1.6%. Thus this improves pair/stack deformation but does not recreate all XPBD shapes/recovery. Lower stiffness increased indentation excessively; rigidity 0.65–0.9 or extra iterations reduced some shape errors but increased jitter/cost. Global native parameters cannot reproduce XPBD's hard deformation limit and all contact modes simultaneously in tested settings.

The selected 10 fixtures repeated twice with identical traces and finite velocities. Live same-level shot merged into level index 1 and can_drop=true. Natural feel remains NEEDS_PLAYTEST. Prior metric tables below are historical, not directly comparable to outline displacement.


## Official 12-particle parameter-only resistance retune

User request: keep stability, increase resistance to deformation, add no code. Only resources/soft_pond_physics.tres changed: rigidity 0.25→0.4, shape matching 0.04→0.12, area rigidity 0.8→1.0. Particle count/springs, 4 iterations, 2 substeps, damping/friction unchanged. Six rigidity/shape combinations and six rigidity/area combinations were compared against current and XPBD; chosen 10 fixtures repeated twice, trace identical. Historical six-control results are recorded for reference; different control layouts/edge sets make strain metrics approximate comparisons.

| Scenario | XPBD peak strain | Historical 6-control peak | 12-point before→after | Tail internal RMS before→after(px/s) |
|---|---:|---:|---:|---:|
| ceiling_small | 11.9% | 9.4% | 20.2→17.5% | 8.75→0.95 |
| ceiling_large | 10.0% | 8.2% | 10.7→7.9% | 2.21→2.22 |
| pair_head | 7.3% | 7.4% | 4.0→3.4% | 0.22→0.11 |
| pair_angle | 6.0% | 7.0% | 3.3→2.5% | 1.10→1.05 |
| stack_hit | 10.5% | 12.6% | 14.3→14.6% | 18.91→9.43 |
| floor_small | 11.7% | 8.9% | 19.6→16.8% | 8.88→0.56 |
| free_shape | 4.6% | 4.5% | 1.0→0.9% | 0.00→0.00 |

Rigidity 0.6/0.8 increased small ceiling/floor tail vibration to roughly 9–13px/s and was rejected. Chosen large ceiling peak strain 7.9% is close to historical six-control 8.2%. Small ceiling/floor still differ from historical compression limits. Stack maximum strain did not improve (14.3→14.6%), although tail RMS fell 18.91→9.43px/s; no universal stability or identical feel claim. Free recovery quiet onset 4→2 updates. Scoped live same-level launched merge produced level index 1, can_drop=true. All chosen fixture velocities finite. NEEDS_PLAYTEST.

## 방법

`tools/compare_soft_pond.gd`를 MCP 실행 중인 60번에서 호출. 동일 원본 윤곽과 6개 제어점, 질량, 초기 위치/속도/회전, 중력으로 각각 180회 60Hz 외부 업데이트. Quark 내부는 2소구간×4회 반복. 6회마다 중심/속도/거리 제약 변형률 기록. XPBD 파라미터는 변경하지 않았다. 최종 10개 시나리오를 3회 반복해 기록된 궤적이 같음을 확인했고, 중간 소구간 GPU/쿼리 윤곽 갱신 생략 후에도 동일했다.

아래 위치 오차는 XPBD 대비 모든 기록 중심의 RMS(px), 변형률은 모든 거리 제약 중 최대 절대 길이 변화율. 화면상의 면적 감소율과 다르다. `before`는 이번 수정 직전 Quark이며 이전 압력 중심 보정은 이미 포함한다. 적층은 각 솔버에서 180회 사전 안정화하므로 초기 접촉 배열도 달라질 수 있어 엄격한 같은 궤적 비교가 아니다.

| 시나리오 | 위치 오차 이전→최종(px) | 최대 변형률 XPBD / 이전 / 최종 |
|---|---:|---:|
| ceiling_small | 2.67 → 0.26 | 11.9% / 114.6% / 10.7% |
| ceiling_slow | 3.30 → 0.37 | 10.7% / 116.4% / 10.6% |
| ceiling_angle | 56.52 → 3.64 | 11.5% / 126.1% / 10.7% |
| ceiling_large | 3.63 → 1.34 | 10.0% / 40.7% / 8.9% |
| pair_head | 31.49 → 2.24 | 7.3% / 3.9% / 9.1% |
| pair_angle | 13.83 → 23.62 | 6.0% / 4.7% / 9.2% |
| pair_large | 41.33 → 3.62 | 3.8% / 2.0% / 4.2% |
| stack_hit | 88.97 → 32.56 | 10.5% / 68.6% / 9.6% |
| floor_small | 4.08 → 11.26 | 11.7% / 116.8% / 11.4% |
| free_shape | 0.01 → 0.02 | 4.6% / 1.2% / 4.2% |

## 선택한 변경

- 공유 제어점의 접촉을 처리한 뒤 다음 접촉의 겹침을 현재 위치에서 다시 계산. 바인딩 가중치와 질량에 따른 유효 역질량으로 양측 보정 분배.
- 2소구간, 거리 제약 10% 제한, rigidity 0.025, shape matching 0.04, area 0.8, 내부 감쇠 18/s, 수면 허용치 0.025. 공 마찰 0.01 / 벽 마찰 0.19. 바닥/천장 외향 속도 유지율 0.03/0.01.
- 바인딩 접촉 마찰은 이전 위치(속도)에 적용. 내부 변형과 회전 감쇠 분리. XPBD와 같이 접촉한 공들의 중심 운동 에너지가 외력 반영 예산을 넘으면 투영해 수치적 증폭 제한.
- 강성·형태복원·마찰·반복 횟수를 여러 조합으로 비교. 반복 2/3회는 작은 공 천장 충돌에서 최대 변형이 45%/24%까지 커져 제외.

## 검증과 한계

- 모든 최종 fixture 속도 유한. 실제 MCP 발사: 1단계 두 공→2단계, can_drop=true. 비스듬한 벽 발사 64 physics ticks와 가이드 polyline 최대 중심 거리 7.93px(움직임 정확 일치 보증 아님).
- 자유 복원 정숙 기준(입자 RMS<12px/s, 중심<6px/s가 45회 유지)에 들어가는 시작: XPBD 8회 / 최종 10회. 천장 소형/대형과 적층은 최종 3초 안에 같은 정숙 기준을 만족하지 못했다. 수면 문제가 해결됐다는 주장은 하지 않는다.
- 정면 충돌·천장 충돌과 자유 복원은 가까워졌지만, 비스듬한 공 충돌과 바닥 이동 거리의 RMS 오차는 이전보다 커졌다. 접촉 위치/법선/마찰 모델이 달라 모든 움직임의 일치를 주장하지 않는다. 자연스러움과 연쇄 합성은 NEEDS_PLAYTEST.
- 48개(0–3 인덱스, 6열×8행) 밀집 fixture, 120 physics ticks 뒤 3초 Godot profiler: 최종 frame elapsed 평균 85.64ms, physics 평균 18.52ms, script 28.95ms. GPU/프레임 대기 및 physics catch-up이 섞이며 시간을 서로 더할 수 없다. 중간 소구간 시각 갱신 생략 전 frame elapsed 91.18ms. 여전히 무거워 성능 개선 완료로 보지 않는다. 과거 문서의 15.12ms는 CPU 처리 항목/구버전 측정이므로 이 전체 elapsed와 직접 비교하지 않는다.
