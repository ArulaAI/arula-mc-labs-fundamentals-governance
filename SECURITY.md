# Security

Completed in **Stage 6 — Governance**, as the closing artifact of this lab run.

## Reporting policy

This is a training lab, not a production service — there is no real cardholder data,
no real production deployment, and no external reporting channel. Within the lab: any
finding a participant identifies is registered in `RISK_REGISTER.md` regardless of
whether it gets fixed this pass. Nothing found is ever silently dropped
(`.claude/rules/ai-use-policy.md` §4-5). Outside the lab, treat this document as the
template for what a real service's `SECURITY.md` should contain: a reporting policy
statement, a table of accepted/open risks, and a table of controls actually in place.

## Security Controls

Controls actually implemented and verified this pass — pulled from `FIXES.md`.

| ID | Control | Verified by |
|---|---|---|
| | | |

<!-- One row per remediated finding (V1, V2 this pass). "Verified by" names the specific
     security test and the pr-reviewer verdict, not just "tested". -->

## Known Risks (Accepted / Open)

Findings registered in `RISK_REGISTER.md` that remain `Open` at the end of this pass —
including V3, which is a real registered finding intentionally left out of this pass's
remediation scope, and the hygiene backlog items that were never in scope to begin with.

| ID | Risk | Severity | Why it's accepted for now |
|---|---|---|---|
| | | | |

<!-- One row per Open RISK_REGISTER.md entry. "Why accepted" states the actual reason
     (out of this pass's target list per .claude/lab.json, or a proactive-control item
     covered instead in docs/secure-features-guide.md) — not a placeholder. -->

## Governance evidence

- **Journey log:** `.claude/journey/<run_id>.jsonl`
- **Quality gate results:** `.claude/quality-gates-latest.json`
- **Fresh-context reviews performed:** <count and outcomes — see `docs/workflow-tracker.md`>
- **Grade:** <output of `/grade`, if run>

## Proactive controls recommended

See `docs/secure-features-guide.md` — not duplicated here.
