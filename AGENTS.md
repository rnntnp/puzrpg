# Repository working rules

These instructions apply to the whole repository.

Before designing or implementing a mechanic, read these files in order:

1. `docs/GAME_CORE_RULES.md`
2. `docs/MECHANIC_REGISTRY.md`
3. `docs/AUTONOMOUS_MECHANIC_WORKFLOW.md`
4. `docs/test_gimmick_architecture.md`

Treat the current scripts and resources as runtime truth. Treat older PDFs and planning notes as design intent when they conflict with runtime behavior. Never silently change a core rule for one mechanic.

For an unspecified autonomous mechanic request, follow the complete workflow in `docs/AUTONOMOUS_MECHANIC_WORKFLOW.md`. For a user-specified mechanic, skip candidate generation but still perform the core-rule, duplicate, behavioral-contract, project-reuse, cleanup, and registry checks.

Mechanic documentation is prototype working documentation. Keep it as concise repository Markdown only (`.md`). Do not create PowerPoint, Word, PDF, Google Docs, or presentation-ready design documents unless the user explicitly requests that artifact in a later task.

The latest registered mechanic is 50. Number 51 is the next available number, but do not create or reserve it unless the user requests a new mechanic.

New test mechanics must use the modular `TestGimmickHandler` structure. Do not add them to `LegacyTestGimmickHandler`, and do not add mechanic-specific branches to `Battle` or `MonsterActionController`. Put mechanic-only tuning in its own Resource and mechanic-only visuals in its own visual layer.

Do not perform project-wide integrity checks, full regression runs, export checks, or full resource scans unless the user explicitly asks. Perform only scoped static checks appropriate to changed files, and never claim that gameplay or fun was validated without a user playtest.
