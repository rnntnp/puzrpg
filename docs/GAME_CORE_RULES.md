# GAME CORE RULES

Last code audit: 2026-08-13  
Scope: the current Godot prototype in this repository

This document is the long-term source of truth for rules shared by campaign stages and mechanic test levels. It records what the current runtime actually does. A planning document does not override a conflicting implementation unless the user explicitly decides to change the core game.

## 1. Evidence and precedence

Use sources in this order:

1. Current scripts, scenes, Resources, and `resources/catalogs/main_level_catalog.tres`
2. This document, `MECHANIC_REGISTRY.md`, and a selected mechanic's document under `docs/mechanics/`
3. `docs/test_gimmick_architecture.md` for implementation structure
4. Planning PDFs, `게임_기획서_정리.md`, and `todo.md` for historical intent

Terms used below:

- **Runtime rule**: directly confirmed in current code or Resource data.
- **Design intent**: documented in a PDF or old planning note but not confirmed in current runtime.
- **Unresolved**: the sources conflict or the inspected project has no implementation.

A new mechanic may extend behavior through its own handler. It must not silently rewrite a runtime rule in this document. If the requested mechanic only works by changing a core rule, stop and ask for that decision.

## 2. Project and level flow

- The main scene is `scenes/loading.tscn`; it opens `scenes/level_select.tscn` after its loading delay.
- `GameSession` loads the single `LevelCatalog` Resource at `resources/catalogs/main_level_catalog.tres`.
- The catalog currently contains 3 campaign levels followed by 50 mechanic test levels.
- Campaign levels unlock sequentially. Every path in `test_level_paths` is always selectable.
- The level-select start button stores the selected path in `GameSession` and opens `scenes/main.tscn`.
- A battle win, fighter defeat, danger-line overflow, or explicit gimmick failure opens `scenes/battle_result.tscn`. Its buttons return to level select.
- `LevelData.enemies` is the existing enemy-sequence system. Enemies are loaded in array order; do not create a second wave manager.
- The board's balls remain in the same `MergeGame` while sequential enemies change. A test handler can also retain its mechanic state by setting `preserve_board_between_enemies`.
- On the last enemy's defeat, the level result is recorded and `next_level_path` is used only when a next catalog entry exists.

Primary runtime evidence: `scripts/game_session.gd`, `scripts/level_catalog.gd`, `scripts/level_select.gd`, `scripts/battle.gd`, and `scripts/battle_result.gd`.

## 3. Player control and dropping

- The player's direct board control is horizontal drop-position selection.
- Mouse motion or screen drag moves the preview. Press begins aiming inside the board; release drops at the clamped X position.
- A blocked drop zone can clamp the selected X to the nearest legal edge.
- `current_level` is the previewed ball and `next_level` is shown in the next panel. Additional queued levels support queue-changing mechanics.
- `LevelData.ball_drop_time_limit >= 0` enables timed auto-drop. A negative value disables it.
- All 3 currently registered campaign levels and all 50 currently registered test levels explicitly use `-1.0`, so they have no normal auto-drop timer.
- After a player ball first contacts another ball, the base floor, or a node in `drop_landing_surface`, the next drop may become available. Side-wall contact alone does not count.

Primary runtime evidence: `scripts/merge_game.gd`, `scripts/merge_ball.gd`, and `scripts/level_data.gd`.

## 4. Ball model

- The runtime catalog has 11 ball stages, indexed `0..10` and displayed as stages `1..11`.
- A level may lower its maximum through `LevelData.max_ball_level`.
- A normal random drop is uniformly selected from indices `0..min(4, max_level_index)`: displayed stages 1 through 5 when the level maximum allows them.
- `BallData` owns the ball's stage metadata, sprite, circle collision shape, glow, and `merge_score`.
- The current ball shape enum only supports circles.
- Runtime base mass is derived from radius: `max(1.0, radius / 20.0)`. It is not stored independently in `BallData`.
- `LevelData.ball_physics_speed` is applied as `gravity_scale = physics_speed²`.
- Stage-specific radius and score values live in `resources/balls/ball_01.tres` through `ball_11.tres`.

Primary runtime evidence: `scripts/ball_catalog.gd`, `scripts/ball_data.gd`, `scripts/merge_ball.gd`, and the ball Resources.

## 5. Normal merge

- Two active, unfrozen balls request a merge only when they have the same stage.
- A locked ball cannot merge. A stage sealed by a mechanic cannot merge while sealed.
- A ball already at the level's maximum stage does not merge. It does not disappear.
- Both source balls are locked and removed. The result is created one stage higher at the midpoint of their positions.
- The current implementation does not transfer the source balls' average velocity to the result. It creates a new result ball, then applies the configured radial merge push to nearby balls.
- The result is a normal ball. It emits the normal merge registration and completion signals and may participate in later chain merges.
- A gimmick-created demotion, removal, duplication, mirror spawn, or terrain move is not automatically a normal merge. A mechanic must explicitly state any exception.
- A mechanic driven by merge events must prevent its own resulting movement from recursively counting as another player input unless its spec explicitly requires that behavior.

Primary runtime evidence: `scripts/merge_ball.gd` and `scripts/merge_game.gd`.

## 6. Drop sequence, turn completion, and chain

- Dropping a ball starts one drop sequence and resets its `combo_count` and `combo_points`.
- Every normal merge resolved while that drop sequence is active increments the combo count.
- The next chain resolution can be delayed by `LevelData.chain_merge_delay` for readability.
- Logical turn completion is emitted after the dropped ball has made its first valid landing contact and no merge has occurred for 500 ms.
- There is a 4,000 ms maximum wait. At that point turn completion is emitted even if the ideal condition was not reached.
- Full board stillness is not required for the base `turn_completed` signal. Some mechanic handlers explicitly call `wait_until_board_settled()` before measuring board state or moving terrain.
- `MonsterActionController.on_ball_dropped()` is connected to this logical `turn_completed` signal despite its historical method name. Mechanic design should reason in completed player turns, not raw input-press events.

## 7. Score, player damage, and combo

- Each normal merge adds the result ball's `BallData.merge_score` to the score.
- Each normal merge independently requests one delayed projectile attack after 0.25 seconds.
- Base damage for that merge is the result ball's `merge_score`.
- Within a drop sequence, damage is:

  `round(base_merge_score × (1 + 0.5 × (chain_index - 1)))`

- Therefore chain 1 uses ×1.0, chain 2 ×1.5, chain 3 ×2.0, and so on.
- The projectile hit is routed through `MonsterActionController.route_player_damage()` before enemy HP is reduced. Ingestion durability or a test handler may absorb or modify it.
- There is no separate runtime attack-queue class and no extra combo-only hit. Multiple merges create multiple projectiles.
- A test handler may implement a documented damage multiplier through `modify_player_damage()`. It must keep the normal merge result and routing unless its mechanic contract explicitly says otherwise.

Primary runtime evidence: `scripts/merge_game.gd`, `scripts/battle.gd`, and `scripts/monster_action_controller.gd`.

## 8. Health and enemy actions

- `CharacterData` owns maximum HP, attack power, and the normal attack interval measured in completed player drops.
- `Fighter` owns current HP, damage, healing, attack animation, and defeat signaling.
- Test levels duplicate the enemy Resource before applying `TestGimmickData` HP, attack, and interval overrides. Shared character Resources are not mutated.
- Without a special skill or test gimmick, the enemy attacks when its completed-drop countdown reaches zero and resets the countdown.
- During an enemy action that changes the board, input may be locked. Handlers that need deterministic measurement explicitly wait for settlement and restore input afterward.

Primary runtime evidence: `scripts/character_data.gd`, `scripts/fighter.gd`, `scripts/battle.gd`, and `scripts/monster_action_controller.gd`.

## 9. Intent and feedback

- Campaign normal attack, ingestion, and ice countdowns use `StatusEffectBar` data.
- Test mechanics use the existing `Battle.update_gimmick_ui(primary, detail)` labels plus an optional mechanic-owned visual layer.
- The project does not have a generic data-driven enemy intent queue. Do not create a second global intent system for one mechanic.
- A mechanic's UI must expose the state used for its next decision, the remaining turns, the player's actionable response, and the result when ambiguity would change play.
- Prototype feedback may reuse existing sprites or use `Node2D`, `Line2D`, `Polygon2D`, `Label`, color overlays, arrows, and simple tweens. Finished art is not required.

## 10. Danger line and game over

- The danger line is positioned at 27.20% of the board height from its top.
- It becomes visible when a landed ball reaches the reveal height corresponding to 80% fill toward the danger line.
- Every normal drop starts a 1.2-second danger grace period.
- After grace, an unlocked ball whose top crosses above the danger line accumulates overflow time. At 0.8 seconds the merge board triggers game over.
- Board-transforming mechanics may call `suppress_danger_line(seconds)` during forced movement. Suppression resets overflow accumulation; it is not permission to disable the danger line for the mechanic's whole active duration.
- Once forced movement and its short suppression finish, balls that genuinely remain over the line are judged normally.

Primary runtime evidence: `scripts/merge_game.gd` and `scripts/danger_line.gd`.

## 11. Campaign mechanics currently present

These are not part of the numbered 1–50 test-mechanic sequence, but future duplicate checks must consider them.

### Ice

- Campaign level 2 contains a basic and an enhanced ice enemy.
- On its action, the controller locks input, waits for board settlement, performs the enemy's normal damage, then freezes eligible balls.
- Frozen balls are static and cannot merge.
- Every normal merge completion damages every frozen ball's ice by 1.
- The basic Resource freezes 1 ball, allows 1 frozen ball, and uses durability 2.
- The enhanced Resource freezes 2 balls, allows 2 frozen balls, and currently also uses durability 2.
- No third ice boss is registered in campaign level 2. Any PDF boss behavior remains design intent, not runtime truth.

### Ingestion

- Campaign level 3 currently contains one recovery-ingestion enemy.
- After a normal attack, it telegraphs and marks the highest-stage eligible ball. On execution that ball is removed from the board and stored by stage.
- During the response window, player merge damage first reduces ingestion durability. Breaking durability returns the swallowed stage immediately after the current preview, then applies a temporary incoming-damage multiplier to the enemy.
- If the response window succeeds, the enemy heals and the swallowed ball is not returned.
- If the enemy dies while holding a ball, that stage is returned to the queue.
- Only the recovery-ingestion variant is registered in the current campaign.

Primary runtime evidence: `resources/levels/level_02.tres`, `resources/levels/level_03.tres`, `scripts/ice_skill_controller.gd`, `scripts/monster_action_controller.gd`, and their skill Resources.

## 12. Skill gauge and Break

- The planning documents describe a player skill gauge, but the inspected runtime has no generic player skill-gauge system. The label named `SkillDurabilityLabel` displays ingestion durability, not a player gauge.
- The inspected runtime has no generic Break meter shared by all enemies.
- Ingestion durability is an interruptible mechanic-specific shield. Several numbered test mechanics call bonus enemy damage “BREAK” in feedback, but that is not evidence of a shared Break subsystem.
- A new mechanic must say “not applicable” for Skill Gauge or Break unless it intentionally reuses an existing concrete system. Do not invent a generic manager just to satisfy a template heading.

## 13. Test-mechanic runtime contract

- `LevelData.test_gimmick` selects the test runtime.
- `TestGimmickController` instantiates `TestGimmickData.handler_script`; an empty handler path uses the legacy compatibility handler.
- New mechanics must extend `TestGimmickHandler`, use an independent tuning Resource, and optionally attach an independent visual layer.
- New mechanics must not be added to `LegacyTestGimmickHandler` and must not add kind-specific branches to `Battle`, `MonsterActionController`, or the shared overlay.
- Handler cleanup disconnects signals, kills tracked tweens, removes attached visual layers, resets shared gimmick UI, and calls `MergeGame.reset_gimmick_state()`.
- Mechanic-specific timers, nodes, collision exceptions, cached references, physics overrides, and pending actions remain the handler's cleanup responsibility.
- A handler that preserves state between enemies receives `transition_enemy()` and must deliberately reset enemy-specific counters in `_on_enemy_changed()`.

Primary runtime evidence: `scripts/test_gimmick_controller.gd`, `scripts/test_gimmick_data.gd`, `scripts/gimmicks/test_gimmick_handler.gd`, and `docs/test_gimmick_architecture.md`.

## 14. Known source conflicts and unresolved decisions

The following are intentionally not harmonized by guesswork:

| Topic | Current runtime rule | Older documented intent | Decision state |
|---|---|---|---|
| Ball stage count | 11 stages | Common PDF describes 10 | Runtime wins until redesign |
| Direct drop pool | Uniform stages 1–5 | Common PDF describes weighted stages 1–4 (40/30/20/10) | Runtime wins until redesign |
| Maximum-stage merge | Maximum stage cannot merge and remains | Common PDF describes maximum pair disappearing | Runtime wins until redesign |
| Merge damage | Result `merge_score` × chain multiplier; one projectile per merge | Common PDF describes result-stage base damage and a combo extra hit | Runtime wins until redesign |
| Turn settlement | Landing + 500 ms merge quiet, maximum 4 s; full stillness is optional per handler | Planning flow implies full-board settlement before enemy action | Runtime wins; state-reading handlers must wait explicitly |
| Result velocity | New result has no inherited average source velocity | Older design notes describe inherited/averaged motion | Runtime wins until redesign |
| Player skill gauge | No generic runtime implementation found | Common PDF includes a skill gauge | Unresolved / not implemented |
| Generic attack queue | No dedicated queue; delayed projectiles are independent | Common PDF describes an attack queue | Unresolved / not implemented |
| Ice boss | Two ice enemies registered | Ice PDF includes a boss phase | Design intent only |
| Ingestion variants | One recovery variant registered | Ingestion PDF describes additional variants | Design intent only |

Changing one of these requires an explicit core-rule decision and an update to this table, affected code, and related mechanics.
