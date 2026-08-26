# MECHANIC REGISTRY

Last static audit: 2026-08-25
Highest registered number: **50**  
Next available number: **51** (not created or reserved)

This registry prevents a new name from hiding an already-tested player decision. The one-line rule is based on the current handler code, not on inferred fun or balance.

## Audit meaning

For this audit, **implemented** means all of the following static evidence exists:

- A level Resource is present in `resources/levels/`.
- Its path is registered in `resources/catalogs/main_level_catalog.tres`.
- It has a `TestGimmickData` kind and either a legacy runtime branch or a modular `handler_script`.
- Its configured enemy array is present.

It does **not** mean the level was successfully played, balanced, or judged fun. No Godot playtest or full-project validation was performed. Every numbered mechanic therefore remains `NEEDS_PLAYTEST` until the user supplies a result.

Runtime types:

- **Legacy**: one-enemy prototype using [`LegacyTestGimmickHandler`](../scripts/gimmicks/handlers/legacy_test_gimmick_handler.gd). These do not have Teach/Twist/Mastery progression.
- **Modular**: three-enemy prototype using its own `TestGimmickHandler`, tuning Resource, and visual layer. The current 31–50 levels preserve board and handler state between enemies.

## Status vocabulary

| Status | Meaning |
|---|---|
| `IDEA` | Candidate only; not selected |
| `SPEC_READY` | Behavioral contract saved; implementation not complete |
| `IMPLEMENTED` | Code and registered test level exist, with scoped static validation |
| `NEEDS_PLAYTEST` | Implementation exists but user gameplay evidence is absent or incomplete |
| `KEEP` | User playtest accepted the concept |
| `RETUNE` | Concept is retained but values or pacing need adjustment |
| `REJECT` | Concept should not continue |
| `COMBINED` | Folded into another registered mechanic; target number must be named |
| `NEEDS_REVIEW` | Evidence is insufficient to assign a stronger state |

## Numbered mechanics

| No. | Mechanic | Core player-facing rule | Runtime evidence | Status | Related / duplicate-check set |
|---:|---|---|---|---|---|
| 1 | 공 거대화 | At its action, the enemy enlarges the highest eligible non-enlarged ball, up to the configured target cap. | Legacy · 1 enemy · [level](../resources/levels/test_01_enlarge.tres) | `NEEDS_PLAYTEST` | 2, 3, 4 |
| 2 | 공 중량화 | At its action, the enemy increases the mass of the highest eligible non-heavy ball. | Legacy · 1 enemy · [level](../resources/levels/test_02_heavy.tres) | `NEEDS_PLAYTEST` | 1, 36, 37, 39 |
| 3 | 공 분열 | The highest-stage landed ball within the upper board band is split once, Twist selects two, and the Boss cascades one target from one ball to two then four two stages lower. | Modular · 3 enemies · [spec](mechanics/003_ball_split.md) · [level](../resources/levels/03_split_stage.tres) · [handler](../scripts/gimmicks/handlers/split_cascade_handler.gd) | `NEEDS_PLAYTEST` | 1, 4, 19 |
| 4 | 공 복제 | The selected eligible ball creates another ball of the same stage at the drop area. | Legacy · 1 enemy · [level](../resources/levels/test_04_duplicate.tres) | `NEEDS_PLAYTEST` | 1, 3, 30 |
| 5 | 좌우 보드 압축 | Repeated actions move both side walls inward in configured steps, reducing board width. | Legacy · 1 enemy · [level](../resources/levels/test_05_compress.tres) | `NEEDS_PLAYTEST` | 6, 7, 25, 34, 42 |
| 6 | 바닥 상승 | Repeated actions raise the base floor in configured steps, reducing board height. | Legacy · 1 enemy · [level](../resources/levels/test_06_raise_floor.tres) | `NEEDS_PLAYTEST` | 5, 21, 25, 39 |
| 7 | 보드 기울이기 | The board alternates tilt direction for a configured duration, changing ball motion. | Legacy · 1 enemy · [level](../resources/levels/test_07_tilt.tres) | `NEEDS_PLAYTEST` | 5, 8, 9, 13, 34, 36 |
| 8 | 수직 충격파 | The enemy applies an upward velocity impulse to all active normal balls. | Legacy · 1 enemy · [level](../resources/levels/test_08_shockwave_vertical.tres) | `NEEDS_PLAYTEST` | 7, 9, 26, 28 |
| 9 | 방향성 충격파 | The enemy alternates left/right horizontal impulses across all active normal balls. | Legacy · 1 enemy · [level](../resources/levels/test_09_shockwave_horizontal.tres) | `NEEDS_PLAYTEST` | 7, 8, 26, 28 |
| 10 | 암석 벽 생성 | A durable rock wall rises in a rotating board section; nearby normal merges reduce its durability. | Legacy · 1 enemy · [level](../resources/levels/test_10_rock_wall.tres) | `NEEDS_PLAYTEST` | 11, 25, 39, 42 |
| 11 | 낙석 | A rock falls into a rotating section and becomes a settled obstacle; nearby merges can damage it. | Legacy · 1 enemy · [level](../resources/levels/test_11_rock_fall.tres) | `NEEDS_PLAYTEST` | 10, 14, 42 |
| 12 | 포탈 위치 변경 | A paired entrance/exit layout alternates; a ball entering the radius is teleported with a short cooldown. | Legacy · 1 enemy · [level](../resources/levels/test_12_portal.tres) | `NEEDS_PLAYTEST` | 18, 30, 34 |
| 13 | 중력장 | A temporary field at one of several positions continuously attracts nearby balls toward its center. | Legacy · 1 enemy · [level](../resources/levels/test_13_gravity_field.tres) | `NEEDS_PLAYTEST` | 7, 21, 26 |
| 14 | 위험 영역 | Balls remaining in the marked third gain hazard turns; at the threshold they lose a stage or are removed. | Legacy · 1 enemy · [level](../resources/levels/test_14_danger_zone.tres) | `NEEDS_PLAYTEST` | 11, 18, 27, 41 |
| 15 | 다음 공 큐 셔플 | The enemy reverses the next three queued ball stages. | Legacy · 1 enemy · [level](../resources/levels/test_15_queue_shuffle.tres) | `NEEDS_PLAYTEST` | 30, 41 |
| 16 | 특정 단계 봉인 | A rotating selected stage is temporarily prevented from normal merging. | Legacy · 1 enemy · [level](../resources/levels/test_16_seal_stage.tres) | `NEEDS_PLAYTEST` | 17, 22, 23, 24, 33 |
| 17 | 단계별 약점 변경 | A rotating result stage deals ×2 damage; other result stages deal ×0.5 damage. | Legacy · 1 enemy · [level](../resources/levels/test_17_weakness.tres) | `NEEDS_PLAYTEST` | 16, 27, 32, 40 |
| 18 | 낙하 영역 제한 | One board third is temporarily blocked as a selectable drop X area. | Legacy · 1 enemy · [level](../resources/levels/test_18_drop_restriction.tres) | `NEEDS_PLAYTEST` | 12, 14, 27, 41 |
| 19 | 공 위치 교환 | Two eligible balls of different nearby stages exchange positions while collision is temporarily disabled. | Legacy · 1 enemy · [level](../resources/levels/test_19_swap.tres) | `NEEDS_PLAYTEST` | 3, 29, 31 |
| 20 | 생명 방울 공격 / 호위 | The enemy attacks a central life bubble; nearby merges grant shield, and destruction fails the level. | Legacy · 1 enemy · [level](../resources/levels/test_20_life_bubble.tres) | `NEEDS_PLAYTEST` | 10, 38 |
| 21 | 수면 상승 / 범람 | Temporary rising water adds damping and upward buoyancy to submerged balls. | Legacy · 1 enemy · [level](../resources/levels/test_flood.tres) | `NEEDS_PLAYTEST` | 6, 13 |
| 22 | 합성 저주 | A telegraphed ball becomes cursed; merging it deals configured counter-damage to the player. | Legacy · 1 enemy · [level](../resources/levels/test_merge_curse.tres) | `NEEDS_PLAYTEST` | 16, 23, 24, 40 |
| 23 | 합성 순서 룬 | Completing the displayed result-stage sequence within its limit damages the enemy and skips the next normal attack. | Legacy · 1 enemy · [level](../resources/levels/test_merge_sequence.tres) | `NEEDS_PLAYTEST` | 16, 22, 24, 40, 41 |
| 24 | 콤보 장벽 | While active, merge damage is remapped by chain position: first, second, and third-or-later. | Legacy · 1 enemy · [level](../resources/levels/test_combo_barrier.tres) | `NEEDS_PLAYTEST` | 16, 22, 23, 40 |
| 25 | 트랩도어 바닥 | A rotating floor third is lowered temporarily, allowing balls to fall into the opened section. | Legacy · 1 enemy · [level](../resources/levels/test_trapdoor.tres) | `NEEDS_PLAYTEST` | 5, 6, 10, 39, 42 |
| 26 | 탄성 범퍼 | A temporary bumper applies a capped radial impulse when balls collide with it. | Legacy · 1 enemy · [level](../resources/levels/test_bumper.tres) | `NEEDS_PLAYTEST` | 8, 9, 13, 34 |
| 27 | 이동 약점 구역 | The weak third moves in a pattern; merges inside and outside use different damage multipliers. | Legacy · 1 enemy · [level](../resources/levels/test_weak_zone.tres) | `NEEDS_PLAYTEST` | 14, 17, 18, 31, 32 |
| 28 | 합성 잔향 | Merge origins are recorded and replayed as radial impulses on the following turn. | Legacy · 1 enemy · [level](../resources/levels/test_merge_echo.tres) | `NEEDS_PLAYTEST` | 8, 9, 26, 34 |
| 29 | 시간 표식 / 위치 되감기 | Eligible settled balls are marked and later returned toward saved positions if they still exist. | Legacy · 1 enemy · [level](../resources/levels/test_rewind.tres) | `NEEDS_PLAYTEST` | 19, 30, 41 |
| 30 | 미러 드롭 보스 | A single boss alternates three preparation drops with three mirrored responses; the phase transition deals no attack damage, while boss-owned merges fire reverse merge projectiles that deal 20% scaled damage to the player. | Modular · 1 boss · [spec](mechanics/030_mirror_drop.md) · [level](../resources/levels/05_mirror_drop.tres) · [handler](../scripts/gimmicks/handlers/mirror_drop_boss_handler.gd) | `NEEDS_PLAYTEST` | 4, 12, 15, 29, 41 |
| 31 | 보드 상태 유도 타겟팅 | The highest height/count third is continuously targeted; the action demotes or removes its highest-stage ball, and the boss alternates the metric. | Modular · 3 enemies · [level](../resources/levels/test_board_state_targeting.tres) · [handler](../scripts/gimmicks/handlers/board_state_targeting_handler.gd) | `NEEDS_PLAYTEST` | 19, 27, 32, 35, 41 |
| 32 | 적 자세 / 행동 유도 | Merge-side majority changes enemy stance; the opposite side can be weak, while an attack can demote the highest ball on the stance side. | Modular · 3 enemies · [level](../resources/levels/test_enemy_stance.tres) · [handler](../scripts/gimmicks/handlers/enemy_stance_handler.gd) | `NEEDS_PLAYTEST` | 17, 27, 31 |
| 33 | 체급 분리판 / 단계 필터 보드 | One-way platforms let stages at or below each side's threshold pass; later modes split and swap thresholds. | Modular · 3 enemies · [level](../resources/levels/test_stage_filter_board.tres) · [handler](../scripts/gimmicks/handlers/stage_filter_board_handler.gd) | `NEEDS_PLAYTEST` | 16, 34, 35, 39 |
| 34 | 합성 동력 지형 장치 | Per-drop left/right merge majority moves a shelf or divider; the boss alternates which device reacts. | Modular · 3 enemies · [level](../resources/levels/test_merge_driven_terrain.tres) · [handler](../scripts/gimmicks/handlers/merge_driven_terrain_handler.gd) | `NEEDS_PLAYTEST` | 5, 7, 26, 28, 33, 39, 42 |
| 35 | 적층 임계선 / 높이 조형 | Each third is read as LOW/HIGH at a line; matching the requested profile damages the enemy and missing it damages the player. | Modular · 3 enemies · [level](../resources/levels/test_profile_height_shaping.tres) · [handler](../scripts/gimmicks/handlers/profile_height_handler.gd) | `NEEDS_PLAYTEST` | 31, 33, 38 |
| 36 | 시소 / 무게 중심 | Board mass distribution tilts a physical seesaw; later enemies require a target balance state for success. | Modular · 3 enemies · [level](../resources/levels/test_seesaw_weight_center.tres) · [handler](../scripts/gimmicks/handlers/seesaw_weight_handler.gd) | `NEEDS_PLAYTEST` | 2, 7, 37, 39 |
| 37 | 무게 압력판 | Ball mass inside left/right plate regions is checked against a target threshold; the boss cycles left, right, and both. | Modular · 3 enemies · [level](../resources/levels/test_weight_pressure_plate.tres) · [handler](../scripts/gimmicks/handlers/weight_pressure_handler.gd) | `NEEDS_PLAYTEST` | 2, 36, 39 |
| 38 | 적층 엄폐 / 레이저 | A stack crossing the cover line absorbs a directional laser and loses one stage; piercing attacks require two covered zones. | Modular · 3 enemies · [level](../resources/levels/test_stack_cover_laser.tres) · [handler](../scripts/gimmicks/handlers/stack_cover_laser_handler.gd) | `NEEDS_PLAYTEST` | 20, 35 |
| 39 | 유리 상승 / 파괴 지형 | Enemy 1 teaches one wide central glass by creating it once and only raising it C1→C2→C3, then releases it on defeat. Enemy 2 uses two independent, non-stacking L1→L2 and R1→R2 glasses. Enemy 3 retains the existing central empty-slot refill pressure rule. Every glass tracks supported ball Stage sum after settlement and transitions Normal → Cracked → Destroyed at its configured thresholds. | Modular · 3 enemies · [level](../resources/levels/test_weight_break_terrain.tres) · [handler](../scripts/gimmicks/handlers/weight_break_terrain_handler.gd) | `NEEDS_PLAYTEST` | 2, 6, 10, 21, 25, 33, 34, 36, 37, 42 |
| 40 | 합성 과열 / Heat | Merges add heat, empty drops cool it, heat changes merge damage, and VENT/IGNITION checks reward opposite heat goals. | Modular · 3 enemies · [level](../resources/levels/test_merge_heat.tres) · [handler](../scripts/gimmicks/handlers/merge_heat_handler.gd) | `NEEDS_PLAYTEST` | 17, 22, 23, 24 |
| 41 | 낙하 흔적 / Drop Memory | Landing thirds are recorded, then replayed as attacks that demote or remove the highest-stage ball in each recorded zone. | Modular · 3 enemies · [level](../resources/levels/test_drop_memory.tres) · [handler](../scripts/gimmicks/handlers/drop_memory_handler.gd) | `NEEDS_PLAYTEST` | 14, 15, 18, 23, 29, 30, 31 |
| 42 | 보드 침입형 적 | Telegraphs announce low/high side arms that enter as temporary physical obstacles, remain for turns, then retract. | Modular · 3 enemies · [level](../resources/levels/test_board_intrusion.tres) · [handler](../scripts/gimmicks/handlers/board_intrusion_handler.gd) | `NEEDS_PLAYTEST` | 5, 10, 11, 25, 34, 39 |
| 43 | 합성 주문 / Merge Order | Complete a displayed merge order by creating a normal merge in the requested zone; later enemies add a visible result stage and a two-step ordered route. | Modular · 3 enemies · [spec](mechanics/043_merge_order.md) · [level](../resources/levels/test_merge_order.tres) · [handler](../scripts/gimmicks/handlers/merge_order_handler.gd) | `NEEDS_PLAYTEST` | 23, 27, 34, 40, 41 |
| 44 | 공 개수 계약 / Ball Count Contract | At contract expiry, required thirds must contain exact ball counts measured from the contract's starting counts; adding without merging raises a count while merging can cancel the net increase. | Modular · 3 enemies · [spec](mechanics/044_ball_count_contract.md) · [level](../resources/levels/test_ball_count_contract.tres) · [handler](../scripts/gimmicks/handlers/ball_count_contract_handler.gd) | `NEEDS_PLAYTEST` | 31, 35, 37, 41, 43 |
| 45 | 합성 연결망 / Merge Link Network | Normal merge origins leave temporary range nodes; success requires the currently displayed beacon set to share one node-connected component. | Modular · 3 enemies · [spec](mechanics/045_merge_link_network.md) · [level](../resources/levels/test_merge_link_network.tres) · [handler](../scripts/gimmicks/handlers/merge_link_network_handler.gd) | `NEEDS_PLAYTEST` | 27, 28, 34, 43 |
| 46 | 합성 스펙트럼 / Merge Spectrum | During each contract, normal merge results fill LOW, MID, or HIGH stage-band slots; Teach needs any two, Twist a specified pair, and the boss all three. | Modular · 3 enemies · [spec](mechanics/046_merge_spectrum.md) · [level](../resources/levels/test_merge_spectrum.tres) · [handler](../scripts/gimmicks/handlers/merge_spectrum_handler.gd) | `NEEDS_PLAYTEST` | 16, 17, 23, 40, 43 |
| 47 | 합성 정산 / Merge Ledger | Normal merge result stages are added as exact ledger values; later modes count only a selected side or require exact left and right totals simultaneously. | Modular · 3 enemies · [spec](mechanics/047_merge_ledger.md) · [level](../resources/levels/test_merge_ledger.tres) · [handler](../scripts/gimmicks/handlers/merge_ledger_handler.gd) | `NEEDS_PLAYTEST` | 23, 27, 40, 43, 46 |
| 48 | 합성 예비군 / Pair Reserve | At each settled checkpoint, unmerged same-stage balls form reserve-pair stages; later modes require multiple distinct stages or different pair stages on the left and right. | Modular · 3 enemies · [spec](mechanics/048_pair_reserve.md) · [level](../resources/levels/test_pair_reserve.tres) · [handler](../scripts/gimmicks/handlers/pair_reserve_handler.gd) | `NEEDS_PLAYTEST` | 16, 31, 33, 44, 46 |
| 49 | 단계 왕관 / Stage Crown | At settled checkpoints, the highest displayed stage in each third must form a unique crown, a tied two-zone crown, or an ascending/descending three-zone staircase. | Modular · 3 enemies · [spec](mechanics/049_stage_crown.md) · [level](../resources/levels/test_stage_crown.tres) · [handler](../scripts/gimmicks/handlers/stage_crown_handler.gd) | `NEEDS_PLAYTEST` | 31, 35, 36, 44, 48 |
| 50 | 단계 인구조사 / Stage Census | Current board populations for displayed stages or stage bands must match exact LEFT-minus-RIGHT count deltas at each settled checkpoint. | Modular · 3 enemies · [spec](mechanics/050_stage_census.md) · [level](../resources/levels/test_stage_census.tres) · [handler](../scripts/gimmicks/handlers/stage_census_handler.gd) | `NEEDS_PLAYTEST` | 33, 36, 44, 46, 47, 49 |

## Non-numbered systems that block duplicates

| System | Confirmed current scope | Status | Duplicate risk |
|---|---|---|---|
| Normal enemy attack | Countdown in completed player drops, then direct player damage | `NEEDS_PLAYTEST` | Any “attack every N drops” mechanic needs an additional decision layer |
| Ice | Campaign level 2 telegraphs targets one completed player turn before freezing; frozen balls cannot merge and all ice loses 1 durability per normal merge | `NEEDS_PLAYTEST` | Ball lock, static obstacle, telegraphed target response, global merge-count damage |
| Ingestion | Campaign level 3 marks and swallows the highest-stage ball; durability can interrupt and return it to the queue. Recovery heals, launch deals direct damage, and the boss alternates both without normal attacks. | `NEEDS_PLAYTEST` | Ball capture, telegraphed targeting, durability shield, queue insertion, success heal/direct damage |
| Danger line | 1.2 s drop grace and 0.8 s overflow; short forced-movement suppression is available | `NEEDS_PLAYTEST` | Any height, compression, rising floor, or forced-physics mechanic |
| Player Weakness skill | Player-owned normal merges charge by result `merge_score`; at 300 the player adds 2 turns to the same ×1.3 Weakness used by ingestion interruption | `NEEDS_PLAYTEST` · [contract](mechanics/player_weakness_skill.md) | Any player gauge, active skill, persistent charge, or generic incoming-damage debuff |

## Validation history and gaps

- Mechanic 1 previously produced reported parse and cleanup errors during user testing. The current source contains the type annotations and NodePath handling added in response, but no completed replay confirmation is recorded here. It remains `NEEDS_PLAYTEST`.
- `automated_smoke_level_paths` currently lists only mechanics 1–20. This is registration metadata, not evidence that those smoke tests ran or passed.
- Mechanics 21–30 are legacy one-enemy levels and are absent from that smoke list.
- Mechanics 31–50 have modular three-enemy Resources and handlers. Their presence is statically confirmed; gameplay completion is not.
- The legacy handler still contains compatibility branches for 31–33, but the currently registered 31–33 Resources explicitly select the modular handlers. The modular path is their active evidence.
- No repository-local detailed behavioral-contract files were found for historical mechanics 1–42. This registry does not fabricate missing intent. Mechanics 43–50 have lightweight prototype contracts under `docs/mechanics/`.
