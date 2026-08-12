---
paths:
  - "docs/plans/**"
  - "docs/**/*spec*.md"
---

# Spec / Plan Template

Adapted from Arula's Forge primitive library `spec_write` template, simplified to what a remediation plan needs — this lab does not run the full interview→draft→self-review spec workflow (that is `spec-craft`'s job, scoped for a later lab in this series). `planner` and `code-to-spec-validator` both target this shape.

## `docs/plans/plan.md` — required structure

```markdown
# Remediation Plan

Generated: <date>
Source: RISK_REGISTER.md

## Steps

### Step 1 — <finding id>: <short name>
- **Severity:** Critical | High | Medium | Low
- **Target file(s):** <paths>
- **Fix:** <one-line description of what changes>
- **Expected post-fix state:** <what should be true once this lands>
- **Success criterion:** <how you know it's done — a test, an observed behavior>

### Step 2 — ...
(one entry per finding actually being remediated this stage, numbered in priority order — Critical before High before Medium before Low)
```

## Validation checklist (what `code-to-spec-validator` checks a plan against)

- [ ] Steps are ordered Critical → High → Medium → Low (no out-of-order severity)
- [ ] Every step names concrete target file(s), not a vague area of the codebase
- [ ] Every step's fix is stated as a single, scoped change — not a bundle of unrelated changes
- [ ] Every step has a success criterion that is actually checkable (a test name, an observable behavior) — not "looks correct"
- [ ] No step proposes a dependency, library, or API that isn't confirmed to exist (cross-check against `payments-guardrails.md` §4)
- [ ] No step scope-creeps into findings not in the current target list
- [ ] Findings intentionally left as backlog are not silently dropped — they remain `Open` in `RISK_REGISTER.md`, not deleted or marked resolved

## `docs/secure-features-guide.md` — required structure

Used for the "secure-future" stage — proactive controls to adopt next, not a remediation plan. No code changes accompany this document.

```markdown
# Secure-Future Guide

## <Control name>
- **What it is:** <one or two sentences>
- **Why it matters here:** <specific to this service — e.g. "prevents double-holds under retry storms"
- **Where it would plug in:** <the layer/component, not full implementation>
```

Each control gets its own section. Do not include code; this is a roadmap document, not an implementation.
