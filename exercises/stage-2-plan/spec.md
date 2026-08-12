# Stage 2 — Spec

## What this stage produces

`docs/plans/plan.md`, matching the structure in `.claude/rules/spec-template.md`, produced
by the `planner` subagent and checked by `code-to-spec-validator`.

## Done means

- Plan file exists, structure matches the template exactly
- Steps ordered Critical → High → Medium → Low
- Every step: target file(s), fix description, expected post-fix state, success criterion
- `code-to-spec-validator` ran against it; any gaps it raised were resolved, not ignored
- Findings not targeted by this plan are still `Open` in `RISK_REGISTER.md`
