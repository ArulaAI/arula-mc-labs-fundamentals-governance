# Security

Completed in **Stage 6 — Close**, as the closing artifact of this lab run.

## Reporting policy

This is a training lab, not a production service — there is no real cardholder data, no real
production deployment, and no external reporting channel. Within the lab: any finding a
participant identifies is registered in `RISK_REGISTER.md` regardless of whether it gets fixed
this pass. Nothing found is ever silently dropped (`ai-use-policy` rule, §4-5). Outside the lab,
treat this document as the template for what a real service's `SECURITY.md` should contain: a
reporting policy statement, a table of accepted/open risks, and a table of controls actually in
place.

## Security Controls

Controls actually implemented and verified this pass — pulled from `FIXES.md`.

| ID | Control | Verified by |
|---|---|---|
| | | |

<!-- One row per remediated finding: F1, F2, F8 this pass. "Verified by" names the specific
     test and the pr-reviewer verdict (or, for F8, the ArchitectureIT/mvn verify result), not
     just "tested". -->

## Known Risks (Accepted / Open)

Findings registered in `RISK_REGISTER.md` that remain `Open` at the end of this pass: F3, F4,
F6, F7, F9, F10 (backlog, never in this pass's scope), and **F5 — explicitly escalated, not
defaulted**, not the same status as the others. F5's row must say so, not just list it as
another backlog item.

| ID | Risk | Severity | Why it's accepted for now |
|---|---|---|---|
| | | | |

<!-- One row per Open RISK_REGISTER.md entry. "Why accepted" states the actual reason (out of
     this pass's target list per .claude/lab.json, or -- for F5 specifically -- that the spec
     pack genuinely does not define the REFUND_EXPIRY window and inventing one would be an
     unauthorised business decision) -- not a placeholder. -->

## Governance evidence

- **Journey log:** `.claude/journey/<session_id>.jsonl`
- **Fresh-context reviews performed:** <count and outcomes — see `docs/workflow-tracker.md`>
- **Grade:** <output of `/grade`, if run>

## Proactive controls recommended

See `docs/secure-features-guide.md` — not duplicated here.
