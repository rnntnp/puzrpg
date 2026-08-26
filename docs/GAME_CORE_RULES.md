# GAME CORE RULES

Last code audit: 2026-08-25
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
- The current level-select order is explicitly controlled by `LevelCatalog.visible_level_paths`; it shows only the selected campaign/test subset while the remaining registered paths stay available in the catalog's hidden arrays for later reconnection.
- A battle win, fighter defeat, or explicit gimmick failure opens `scenes/battle_result.tscn`. Danger-Line overflow removes the overflowing balls and damages the player; it opens the result only if that damage defeats the player.
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
- Stages use circle collision by default. Displayed stage 3 is the explicit exception: it uses a heart outline and a compound dynamic hitbox made from one convex lower body plus two circular upper lobes.
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
- A handler may bracket an enemy-owned physical drop with the opt-in external merge window and tag that drop with the window's unique ownership token. Only merges containing a ball with the active token use the isolated combo and external damage signal; unrelated or previously queued player merges keep player score, combo, and merge projectiles. By default, result balls inherit the active token so only that enemy drop's direct chain remains externally owned. The Mirror Drop Boss additionally marks its spawned ball with a persistent black damage background: that marked ball's next merge remains enemy-owned even after the window closes, consumes the mark, damages the player, and creates an unmarked normal result without inheriting the token.
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

  `round(base_merge_score × (1 + 0.25 × (chain_index - 1)))`

- Therefore chain 1 uses ×1.0, chain 2 ×1.25, chain 3 ×1.5, chain 4 ×1.75, and chain 5 or later uses the ×2.0 cap.
- The projectile hit is routed through `MonsterActionController.route_player_damage()` before enemy HP is reduced. Ingestion durability or a test handler may absorb or modify it.
- There is no separate runtime attack-queue class and no extra combo-only hit. Multiple merges create multiple projectiles.
- When an enemy has begun its defeat transition and another enemy remains in the same level, player merge attacks that reach the delayed attack-request point before the next enemy is configured are retained. After the next enemy is ready, those retained requests create their normal projectiles toward that enemy. This retention does not emit merge registration/completion again, grant score or gauge again, or damage ice again.
- A projectile that was already created before its target enemy died is not retargeted or retained. If it reaches the shared fighter while battle damage is inactive, its hit is discarded. Retained requests are also discarded after the final enemy, player defeat, gimmick failure, or board game-over.
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

## 10. Danger line and overflow

- The gameplay board is the rectangle from the current player-ball drop Y to the floor Collision top; the tall side-wall Collision above the drop point is not gameplay-board height. The danger line position is the `MergeGame.danger_line_height_ratio` Inspector value (default 10% from that gameplay-board top). Mechanics that need player-facing vertical placement may use `MergeGame.get_playable_board_bounds()`.
- Only balls that have completed their first valid landing contact are eligible; a newly dropped ball falling through the line is not eligible until it lands.
- A landed ball enters WARNING when its center reaches the configurable `warning_distance` below the line. WARNING has no countdown.
- One or more eligible ball centers above the line enter DANGER. The board-level timer starts once at the configurable `danger_duration` (default 3.0 seconds) and does not reset when additional balls cross.
- During DANGER, the player may keep dropping. If no eligible centers remain above the line, the timer is cancelled and the state returns to WARNING or SAFE.
- On expiry, all currently overflowing eligible balls are removed and the player takes one configurable `overflow_damage` event (default 10), regardless of ball count. This is not a board instant-death condition.
- The timer pauses while board input is locked or a mechanic calls `suppress_danger_line(seconds)`. Once normal input resumes, existing overflow is re-evaluated without resetting the timer.
- Danger-Line damage uses the normal player HP/defeat path.

Primary runtime evidence: `scripts/merge_game.gd` and `scripts/danger_line.gd`.

## 11. Campaign mechanics currently present

These are not part of the numbered 1–50 test-mechanic sequence, but future duplicate checks must consider them.

### Ice

- Campaign level 2 presents the basic, enhanced, and boss ice enemies in that order.
- One completed player turn before its action, the controller selects eligible balls and marks them with the freeze telegraph. When the player starts the action-triggering drop, input locks immediately so first contact cannot enable another drop. After landing and the final 500 ms merge-quiet window, the enemy freezes the marked lineage and input unlocks only after the full skill finishes. At resolution, a marked ball not already committed to a merge is cast-reserved so it cannot start another merge. A marked ball already `merge_locked` is allowed to finish that committed merge; its result inherits the slot, is reserved before the next physics merge can begin, and is then frozen. Missing results wait up to 500 ms before the slot retargets. Target tracking remains active until each slot freezes or definitively fails. All three current ice actions are freeze-only; their stored attack-power values are reserved for separately scheduled normal attacks. If two marked balls merge together, the result keeps one mark and the duplicate slot immediately searches for a new telegraphed target.
- Frozen balls are static and cannot merge.
- Every normal merge completion damages every frozen ball's ice by 1.
- Completed ice persists across the level's enemy transitions. On enemy defeat, uncast telegraphs, pending merge-result slots, and cast reservations are cancelled, while an already-launched ice projectile is allowed to land and apply its snapshotted durability. A delayed merge result inherits a mark only when one of its source IDs is still owned by the controller's current uncast target list, preventing a defeated enemy's mark from transferring into the next enemy.
- All three ice enemies repeat `ice skill → normal attack → ice skill`. Ice actions deal no direct damage. After each ice action they wait 2 completed turns for the low-damage normal attack; after that attack they wait their configured 3/3/4 turns for the next ice action, producing effective ice recurrence periods of 5/5/6 turns.
- The basic Resource has 600 HP and normal-attack damage 4. It waits 3 turns for its ice action, gathers up to 6 unfrozen candidates in normal priority order, randomly freezes 1 of them with durability 2, and uses the normal reinforcement fallback only when no unfrozen candidate exists.
- The enhanced Resource has 800 HP and normal-attack damage 5. Unlike the other two ice enemies, it starts with its 2-turn normal-attack countdown, then waits 3 turns for its first 2-ball ice action. It gathers up to 6 unfrozen candidates in normal priority order, randomly selects 2 of them, and uses durability 2. Shortages use the normal reinforcement and stage-priority fallback.
- The boss has 900 HP and normal-attack damage 6. It waits 4 turns for its ice action, collects up to 6 unfrozen candidates in normal stage-priority order and randomly chooses 1 as the center, then selects the 2 nearest unfrozen balls regardless of stage, for 3 total targets with durability 3. If no unfrozen center candidate exists or fewer than 2 nearby unfrozen balls exist, the remaining slots use the normal reinforcement and stage-priority fallback.
- There is no frozen-ball cap. The controller first searches stages from the preferred minimum through stage 11 in pool order: unfrozen balls, damaged frozen balls, then full frozen balls. Only if slots still remain does it search lower stages from the nearest lower stage through stage 1 in the same pool order. Re-freezing any frozen ball adds the acting enemy's configured durability to its current durability, including damaged ice. A shortage remains possible only when fewer distinct valid balls than the requested count exist or a selected target becomes invalid before impact. The configured shortage multiplier is inactive while these actions remain freeze-only because they deal no direct damage.

### Ingestion

- Campaign level 3 contains a recovery-ingestion enemy, a launch-ingestion enemy, and an alternating ingestion boss in that order.
- After a normal attack, it telegraphs and marks the highest-stage eligible ball. On execution that ball is removed from the board and stored by stage.
- During the response window, only player merge attacks whose collision occurred after the response began reduce ingestion durability. Attacks belonging to the telegraph-ending drop (including delayed physical merges and their delayed projectiles) still damage enemy HP. Breaking durability spawns the swallowed stage as an independent physics ball falling vertically from a random safe board X, without changing the player's current or queued drops, then adds 2 turns to the shared ×1.3 Weakness effect.
- The recovery variant heals when the response window expires. The launch variant starts with ingestion and deals configured direct player damage using the normal attack animation when the response window expires.
- The boss has no normal attack phase. It alternates launch and recovery ingestion, immediately telegraphing the next ingestion after each success or interruption. Launch ingestion currently gives 4 response turns, while recovery ingestion gives 3; its launch damage scales to a configured cap while ingestion durability remains fixed.
- The swallowed ball is not returned on monster success.
- If the enemy dies while holding a ball, that stage is returned through the same independent random-X board drop.

Primary runtime evidence: `resources/levels/level_02.tres`, `resources/levels/level_03.tres`, `scripts/ice_skill_controller.gd`, `scripts/monster_action_controller.gd`, and their skill Resources.

## 12. Player skill gauge, Weakness, and Break

- `CharacterData.player_skill` optionally enables the shared player skill system. The current blue player uses a maximum gauge of 300 and adds 2 turns to Weakness in `resources/skills/player_weakness.tres`; the shared ×1.3 incoming merge-damage multiplier lives in `resources/effects/ingestion_vulnerable.tres`.
- Every player-owned normal merge immediately grants the result ball's `BallData.merge_score` as gauge. Combo scaling, routed/final damage, defenses, ingestion durability, and damage multipliers do not change this gain.
- Enemy-owned external merges, overflow removal, mechanic removals, and non-merge damage grant no gauge.
- Gauge is capped at its maximum, starts at 0 for each stage, persists across the stage's enemy sequence, and is discarded when the battle scene ends.
- At maximum gauge, the player may use the skill between completed drops while a living current enemy exists and board input is available. Use resets the gauge to 0.
- Weakness belongs to the current enemy. Player skill use and ingestion interruption add their configured turns to the same remaining-turn counter and status icon. It loses one turn at each completed player turn and is removed on enemy defeat instead of transferring to the next enemy.
- Weakness multiplies merge projectile damage once after test-gimmick routing and before ingestion routing, so it increases both ingestion-durability damage and any HP damage left after durability absorption. It does not alter gauge gain.
- The icon above the player fills from grayscale to color bottom-to-top; full charge adds a pulsing aura. The enemy's existing status-effect bar displays Weakness and its remaining turns.
- The inspected runtime still has no generic Break meter shared by all enemies. Ingestion durability is an interruptible mechanic-specific shield, and numbered mechanics using “BREAK” feedback are not a shared Break subsystem.

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
| Player skill gauge | Player-owned normal merges grant result `merge_score`; the configured skill persists through enemy transitions and adds 2 turns to the shared ingestion Weakness | Older notes commonly describe result-stage damage and a combo extra hit | Runtime implementation wins; gauge follows runtime merge damage units |
| Generic attack queue | No dedicated queue; delayed projectiles are independent | Common PDF describes an attack queue | Unresolved / not implemented |
| Ice boss | Three ice enemies are registered; the boss freezes two balls with durability 3 and has no frozen-ball cap | Ice PDF includes a boss phase | Runtime wins; any differing PDF boss behavior is design intent only |
| Ingestion variants | Recovery, launch, and alternating boss variants are registered in campaign level 3 | Older ingestion documents describe the same broad progression with differing tuning | Runtime tuning wins |

Changing one of these requires an explicit core-rule decision and an update to this table, affected code, and related mechanics.
