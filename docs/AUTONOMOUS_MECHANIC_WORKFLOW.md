# AUTONOMOUS MECHANIC DEVELOPMENT WORKFLOW

This is the repository-local operating version of the user's autonomous design instructions. It is a workflow for one mechanic at a time, not permission to redesign the whole project.

All mechanic documentation produced by this workflow is lightweight prototype documentation in Markdown. Do not generate PPT, PPTX, DOCX, PDF, Google Docs, or presentation-ready planning artifacts unless the user explicitly asks for one later. The user will prepare formal design documents after the test phase.

## 1. Entry modes

### Autonomous request

Examples: “다음 기믹 만들어줘”, “새 테스트 레벨 하나 추가해줘”.

Run the complete discovery, evaluation, selection, specification, implementation, registration, and reporting flow below. Generate many candidates, but implement only one unless the user explicitly asks for more.

### User-specified mechanic

Examples: “시소를 구현해줘”, or an attached detailed spec.

Skip candidate generation and scoring. Still check core-rule compatibility, registry duplication, gameplay ambiguity, edge cases, project reuse, cleanup, test-level registration, and registry status. Do not add rules that the supplied behavioral contract does not require.

## 2. Mandatory sources

Read in this order before choosing or implementing anything:

1. `docs/GAME_CORE_RULES.md`
2. `docs/MECHANIC_REGISTRY.md`
3. The relevant file under `docs/mechanics/`, if one exists
4. `docs/test_gimmick_architecture.md`
5. Current related code and Resources

The registry's highest confirmed number determines the next number. As of the 2026-08-13 audit, 50 is highest and 51 is next, but this value must be re-read from the registry at the start of every new task.

## 3. Full autonomous sequence

1. Read core rules and current related documents.
2. Read the registry and confirm the latest number and related mechanics.
3. Generate at least 8 genuinely different candidates. Use 10–15 when the first set clusters around one idea.
4. Apply the Suika-control hard gate.
5. Write 1–2 concrete expected-play scenarios for each surviving candidate.
6. Check fun, intentional player response, agency, repetition, visible differentiation, and expansion.
7. Score each survivor out of 100; record confidence and implementation difficulty.
8. Select one highest-priority candidate. A lower-scoring candidate may be chosen only when the leader has low confidence, high implementation risk, or strong duplication.
9. Perform the final one-sentence duplicate check against the registry.
10. Design Enemy 1 as Teach, Enemy 2 as Twist, and Boss as Mastery.
11. Write the detailed behavioral contract.
12. Resolve only edge cases that change gameplay results.
13. Remove implementation leakage from the design document.
14. Save the selected lightweight Markdown spec under `docs/mechanics/NNN_snake_case.md`.
15. Inspect only the current project structures needed to implement it.
16. Write a reuse plan for existing Stage, enemy sequence, turn, merge, damage, intent, board, and level registration systems.
17. Implement the prototype with mechanic-owned tuning and cleanup.
18. Register one actually enterable test level with Enemy 1 → Enemy 2 → Boss.
19. Add readable prototype feedback using existing art and simple shapes/UI.
20. Perform scoped minimum self-validation only.
21. Update the registry to `NEEDS_PLAYTEST` and record runtime evidence.
22. Report the requested files, entry method, tuning locations, deviations, and user playtest questions without claiming successful gameplay.

Use `docs/templates/mechanic_candidate_review.md` during selection and `docs/templates/mechanic_spec.md` for the selected contract.

## 4. Candidate hard gates

### Suika control fit

Reject a candidate if the player cannot materially affect its outcome using the existing horizontal drop selection and normal merge system.

For each survivor, answer:

- Can the player reasonably attribute success or failure to a drop choice?
- Could a different drop X or merge setup produce a different outcome?
- Does the mechanic change a meaningful decision rather than merely add spectacle?

### Expected play

Each candidate needs a concrete scenario containing:

- Information the player sees
- Action the player can take
- Mechanic result
- Short causal explanation

Do not use idealized physics precision. The scenario should remain plausible in the actual board.

### Fun and agency

State the specific satisfying moment: redirecting an attack, exploiting danger, preparing a collapse, manipulating order, shaping a stack, or another observable payoff.

Reject or revise candidates dominated by unanswerable randomness, one obvious repeated answer, or outcomes the player cannot influence after reading the warning.

### Expansion

Enemy 1, Enemy 2, and Boss must differ by rules or decisions, not only HP, damage, shorter timers, or larger thresholds. Boss should combine learned rules before adding a new control verb.

List at least three natural later variants: rule, target, position, stage, timing, enemy-AI, cross-mechanic, or boss-pattern variations.

### Prototype visualization

Reject or revise a candidate whose state, cause, and result cannot be made readable with current sprites plus shapes, labels, lines, arrows, color, progress bars, or simple tweens. Finished art is not required.

## 5. Scoring

| Category | Maximum |
|---|---:|
| Suika Control Fit | 20 |
| Expected Fun | 20 |
| Intentional Player Response | 15 |
| Enemy 1 → Enemy 2 → Boss Expansion | 15 |
| Multi-Level Expansion | 15 |
| Readability / Visible Differentiation | 5 |
| Implementation Feasibility | 10 |
| **Total** | **100** |

Interpretation:

- 80–100: preferred prototype candidates
- 70–79: revise and re-evaluate
- 0–69: do not select without a documented exceptional reason

Record confidence as High, Medium, or Low and implementation difficulty as Low, Medium, or High. Score describes expected prototype value, not proven fun.

## 6. Behavioral-contract rules

The mechanic spec defines game results, not the code recipe. It must make these points unambiguous when relevant:

- What the player sees and when it appears
- Trigger and decision time
- Exact state-reading moment
- Legal player responses
- Success and failure results
- Teach, Twist, and Mastery rules plus expected play
- Normal merge, chain, damage, combo, Skill Gauge, Break, and Danger Line relationships
- Enemy transition and board persistence
- Tie, empty-target, final-drop, enemy-death, restart, and cleanup outcomes
- Prototype starting values and Inspector/data tuning location
- Required visible feedback
- User playtest questions

Write “not applicable” when the project has no relevant shared system, such as the current generic Skill Gauge or Break system. Do not invent one to fill a heading.

Avoid implementation leakage: manager names, helper names, enum members, node hierarchies, array layouts, and exact script names belong to implementation unless they change gameplay behavior.

## 7. Project reuse and implementation

Inspect existing systems before adding code:

- `LevelData` and `LevelCatalog`
- `Battle` enemy sequence and result flow
- `MonsterActionController`
- `MergeGame` signals and board helpers
- `MergeBall` stage, mass, collision, and merge state
- `TestGimmickController`, `TestGimmickData`, and `TestGimmickHandler`
- Existing intent/status UI and Danger Line handling

Use the current modular test structure:

- Mechanic tuning Resource under `scripts/gimmicks/configs/`
- Mechanic handler under `scripts/gimmicks/handlers/`
- Mechanic visual layer under `scripts/gimmicks/visuals/` when needed
- Test-level Resource under `resources/levels/`
- Existing enemy Resources or mechanic-specific Resources only when data must differ
- Registration in `resources/catalogs/main_level_catalog.tres`

Do not:

- Add a new mechanic to `LegacyTestGimmickHandler`
- Add mechanic-specific branches to `Battle` or `MonsterActionController`
- Add mechanic-specific drawing branches to the shared overlay
- Mutate shared Resources at runtime
- Create a universal manager for a single prototype
- Add a second enemy-wave, intent, turn, merge, or level-select system

Use `enemy_healths` for per-enemy prototype HP and `preserve_board_between_enemies` when Teach → Twist → Mastery must share the board.

## 8. Cleanup and physics safety

Every temporary node, timer, tween, signal connection, collision exception, collision-layer change, material/physics override, cached target, and pending action needs an explicit lifecycle.

Cleanup must be safe on:

- Enemy defeat and transition
- Final enemy defeat
- Player defeat or gimmick failure
- Scene exit and restart
- Handler replacement

Short Danger Line suppression is allowed during forced board movement. Re-enable normal judgment after the transition; do not hide a genuinely overflowing board for the mechanic's entire duration.

Normal merges caused after terrain motion remain normal merges, but they must not recursively count as new terrain-control input in the same player turn unless the spec says so.

## 9. Minimum self-validation

Only validate the changed scope:

- Obvious parse/type errors in changed scripts
- New scene/Resource/script paths exist
- The test level is in `test_level_paths`
- Enemy 1, Enemy 2, and Boss are assigned
- `handler_script`, tuning Resource, and visual references agree
- Cleanup and enemy-transition paths exist
- The registry and mechanic spec match the code's observable rule

Do not perform full regression, all-level execution, full resource integrity, export validation, or project-wide playtests unless the user explicitly requests them.

Static inspection is not a playtest. Finish at `NEEDS_PLAYTEST` and give the user concrete questions to verify in Godot.

## 10. When user input is required

Choose reasonable prototype values, UI forms, Resource layout, node types, and reuse details without repeated questions.

Ask only when every safe alternative still requires one of these decisions:

- A change to `GAME_CORE_RULES`
- Two plausible interpretations with materially different gameplay
- A large redesign of an existing shared system
- A direct conflict with a user-confirmed rule
- A change to the existing drop-control model

Before asking, try another candidate or a smaller implementation that preserves the core rules.

## 11. Completion and registry transitions

After spec only: `SPEC_READY`.

After code and test-level registration: implementation evidence recorded and status `NEEDS_PLAYTEST`.

Only user playtest evidence can move it to:

- `KEEP`
- `RETUNE`
- `REJECT`
- `COMBINED`

Classify reported issues before changing code: Concept, Control, Readability, Tuning, Physics, Implementation, or Content. Do not treat every failed playtest as a tuning problem.
