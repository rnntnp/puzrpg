# Mechanic specification directory

Store the selected behavioral contract for each newly designed mechanic here.

These are lightweight prototype notes only. Keep them in Markdown and focused on testable rules, values, and playtest questions. Do not turn them into PPT, Word, PDF, or presentation-ready design documents; formal planning artifacts are deferred until the user requests them.

## Naming

Use a three-digit registry number and a concise snake-case name:

`NNN_mechanic_name.md`

Example format only: `048_example_name.md`. This example is not a reservation or an implemented mechanic.

The registry currently ends at 47. Re-read `docs/MECHANIC_REGISTRY.md` before assigning any number.

## What belongs here

- The player-facing mechanic rule
- Trigger and state-reading timing
- Teach, Twist, and Mastery behavior
- Expected play
- Important result-changing edge cases
- Core-system relationships
- Prototype starting values
- Required visible feedback
- User playtest questions

Do not turn the design contract into a code blueprint. Script names, helper functions, node hierarchies, and internal arrays should be chosen after inspecting the current project.

## Historical mechanics

The repository does not currently contain reliable detailed specification files for mechanics 1–42. Their code-confirmed behavior and evidence are recorded in `docs/MECHANIC_REGISTRY.md`. Do not create 42 retrospective spec files by inference. Add a historical spec only when an original document or a new user decision supplies the missing contract.
