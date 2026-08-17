# Stage 2 — Plan

**Goal:** an ordered remediation plan, Critical first, scoped to exactly F1, F2, and building
`processOnlineRefund()` — nothing else.

## Steps

1. Invoke the `planner` subagent:
   ```text
   Using RISK_REGISTER.md and specs/refunds-s2i-phase1.spec.md, produce a remediation
   plan scoped to F1 and F2 plus building processOnlineRefund(). For each step:
   target file(s), one-line fix or build task, expected post-fix state, success
   criterion. Critical first. Save to docs/plans/plan.md.
   ```
2. Review the plan yourself against the plugin's `payments-guardrails` rule and the spec's own
   acceptance criteria before moving on. Close any gap you find — don't accept a plan that
   silently expands scope (e.g. a step that also touches F3–F14) or silently narrows it (e.g.
   no step for the online-path build at all).

## Acceptance criteria

- [ ] `docs/plans/plan.md` exists, Critical-severity steps first
- [ ] Every step maps to F1, F2, or the `processOnlineRefund()` build — nothing else
- [ ] Each step names its target file(s) and a concrete success criterion

## Hand-off

`/hand-off` — cite `docs/plans/plan.md` as this stage's artifact.
