# Stage 2 — Plan

**Goal:** Turn your registered findings into an ordered, checkable remediation plan —
before writing any fix.

## Steps

1. Decide which registered findings are in scope for this remediation pass (typically:
   everything Critical and High; Medium/Low may stay backlog — your call, but state it).
2. Invoke the `planner` subagent (see [`.claude/agents/planner.md`](../../../.claude/agents/planner.md))
   in Mode 1, giving it `RISK_REGISTER.md` and your target finding-ID list.
3. `planner` writes `docs/plans/plan.md` using the structure in
   `.claude/rules/spec-template.md` — steps ordered Critical → High → Medium → Low, each
   with target files, a fix description, expected post-fix state, and a concrete success
   criterion.
4. Invoke `code-to-spec-validator` in Mode A against the plan. If it reports gaps, address
   them — do not proceed to Stage 3 with a plan the validator flagged.

## Acceptance criteria

- [ ] `docs/plans/plan.md` exists and matches the template structure exactly
- [ ] Steps are ordered by severity, most severe first
- [ ] Every step names concrete target files (not "the auth service" as a whole)
- [ ] Every step has a checkable success criterion — a test name or an observable behavior
- [ ] `code-to-spec-validator` has run against the plan with no unresolved gaps
- [ ] Findings deliberately left out of this plan remain `Open` in `RISK_REGISTER.md`

## Hand-off

Log this stage in `docs/workflow-tracker.md`: which findings you targeted, what the
validator flagged (if anything), and how you resolved it.
