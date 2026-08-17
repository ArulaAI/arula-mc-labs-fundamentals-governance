# AGENTS.md — lab-refunds-s2i

This file is the canonical instruction set for Claude Code (and any future harness) working
in this repository. `CLAUDE.md` imports it directly.

## What this repo is

**Lab 1: Finish the Refund — Foundations, Governance and the Five Failure Modes** — a Spring
Boot refunds service built on Mastercard PGS's real backlog thread `G1190-3291` (Support Refunds
for S2I transactions, Phase 1), used to teach governed, audited, fresh-context-reviewed
AI-assisted engineering on payment-grade code. Participant-facing flow lives in
[LAB_ACTION_GUIDE.md](LAB_ACTION_GUIDE.md); architecture/prerequisites in [README.md](README.md);
facilitator-only answer key in [docs/FACILITATOR_KEY.md](docs/FACILITATOR_KEY.md).

## Prerequisites

- Claude Code, latest version (this repo depends on the `workbench` plugin, which requires
  2.1.177+ per its own `docs/ARCHITECTURE.md` — no floor to manage below that, build against
  latest).
- The `workbench` plugin installed from the private marketplace:
  `claude plugin install workbench@<marketplace>` (confirm the exact marketplace name before
  session day — the plugin repo's own marketplace folder was deliberately removed, see its
  commit history).
- JDK 17 (Zulu recommended), Maven 3.9+. `~/.m2` should be pre-warmed on lab machines before
  session day.

## Commands (from the `workbench` plugin)

| Command | Purpose |
|---|---|
| `/lab` | Reports lab id, remediation targets, rubric, and time budget from `.claude/lab.json` |
| `/hand-off` | Closes out the current stage, appends to `docs/workflow-tracker.md` |
| `/grade` | Runs `lab-grader` against `.claude/rubrics/finish-the-refund.rubric.yaml` |

`.claude/lab.json`: `{"id":"finish-the-refund","targets":["F1","F2"],"rubric":".claude/rubrics/finish-the-refund.rubric.yaml","minutes":120}`.
**Only F1 and F2 are remediation targets this pass, plus building `processOnlineRefund()`.**
F8 gets resolved too, but mechanically — the build itself won't go green until it's fixed
(see Seeded findings, below). F3–F7 and F9–F16 are registered/backlog, not remediation targets.

## Rules that apply to every change in this repo (from the `workbench` plugin)

Read these before making any change — they are not optional context, they are the review bar:

- `payments-guardrails.md` — cardholder-data handling, PAN/authorization-code masking, ISO 8583
  field constraints, no invented dependencies, smallest diff, backlog discipline
- `ai-use-policy.md` — human-in-the-loop, fresh-context review, logged assumptions, no scope
  creep, full auditability, synthetic data only
- `coding-standards.md` — Java/Spring Boot baseline, testing and git conventions
- `spec-template.md` — required structure for `docs/plans/plan.md` and
  `docs/secure-features-guide.md`

## Subagents (from the `workbench` plugin)

Subagents run in **fresh context** — they never inherit the reasoning or self-confidence of the
session that did the work, which is the whole point (see `ai-use-policy.md`):

| Agent | Purpose | Tools |
|---|---|---|
| `planner` | Turns `RISK_REGISTER.md` into an ordered `docs/plans/plan.md`, or produces `docs/secure-features-guide.md` (guide mode) | Read, Bash |
| `pr-reviewer` | Skeptical, read-only review of a diff against `coding-standards.md` — cannot Write or Edit | Read |

`code-to-spec-validator` and `clean-room-judge` also ship in the plugin but are not used in Lab
1 by design — they're introduced starting Lab 2. Don't invoke them here; it would blur the
pedagogical progression the series is built around.

## Automatic governance (hooks, from the `workbench` plugin)

Active once the plugin is installed. Repo-local hooks are forbidden only where they would
duplicate plugin-provided functionality:

- **Journey recording** (`journey_record.py`) — appends a redacted event to
  `.claude/journey/<session_id>.jsonl` (this repo sets `WORKBENCH_JOURNEY_DIR=.claude/journey`
  in `.claude/settings.json`) on every tool use and session boundary. PAN/secret patterns are
  redacted before writing.
- **Quality gates** (`quality_gates.py`) — secret/PAN scan on every tool call, plus lint/coverage
  on the fuller `mvn verify` pass. This is a reporting gate, not a blocking one — see
  `gate_guard.py` below for the actual blocking mechanism.
- **Gate-guard** (`gate_guard.py`) — repo-local at `.claude/hooks/gate_guard.py`, blocks
  `Write`/`Edit`/`MultiEdit`/`NotebookEdit` calls whose target path matches
  `.claude/gate-guard.json`'s deny list. This repo denies `reference/**` — the Stage-4 fallback
  folder stays read-only during a live session. The plugin ships no blocking equivalent
  (`quality_gates.py` is reporting-only), so a local copy does not drift out of sync.
- **Lab grader** (`lab-grader` skill, wired via `/grade`) — against
  `.claude/rubrics/finish-the-refund.rubric.yaml`; deterministic, same journey file always
  yields the same score. Fallback: if the `workbench` plugin is not installed, run
  `python3 .claude/scripts/grade_repo.py` from the repo root for the same deterministic grader
  logic. See the rubric file's own header comment for a documented limitation: it can verify
  repo-artifact *content* (via `file_contains*` checks) but cannot yet verify a build's pass/fail
  result from the journey log alone — that's the facilitator's live Stage-4 spot-check, not a
  rubric gap to silently paper over.
- **ArchUnit** (`ArchitectureIT`, in this repo's own test suite, not the plugin) — build-blocking
  in `mvn verify` from day one. See F8 below.

## The seeded findings

Fourteen findings are seeded on purpose, every one traceable to `pgs-lab-spec-pack.md` (Spec 1).
Two get fixed by hand, one is caught mechanically by the build, the rest are registered and
deliberately left as backlog. Full detail (smallest-diff outline, exact test assertions, live
traps) is in [docs/FACILITATOR_KEY.md](docs/FACILITATOR_KEY.md), facilitator-only — do not "fix"
anything beyond F1/F2/F8 ahead of time or point findings out unprompted.

| | Finding | Failure mode | Where | Action |
|---|---|---|---|---|
| F1 | Authorization code and full refund record logged at INFO; raw request context logged on failure | Sensitive data leak | `RefundService` | **Fix** |
| F2 | No idempotency — a retried refund creates a second record; 409 never returned | Incorrectly solving the right problem | `RefundService.processOfflineRefund` | **Fix** |
| F3 | `voidRefund()` answers on `POST /card-payments/{card_payment_gateway_id}/void` — Void is explicitly out of scope | Correctly solving the wrong problem | `RefundController` | Register |
| F4 | `PreRiskAssessmentClient` called — spec has no pre-risk-assessment step | Hallucinated dependency | `service/PreRiskAssessmentClient.java` | Register |
| F5 | `REFUND_EXPIRY` privilege exists; the window's value is genuinely undefined in the spec pack | Unauthorised default if silently invented | `RefundPrivilege` | Register + escalate — do not default it |
| F6 | No gate on the excessive-refund path checking `EXCESSIVE_REFUNDS` | Missing privilege gate | `RefundService` | Backlog (live trap during Stage 4's online-refund build — see FACILITATOR_KEY) |
| F7 | No correlation ID propagated end-to-end | — | `RefundController` | Backlog |
| F8 | Controller depends on `RefundRecordDao` directly; privilege check lives in the controller | Layering violation | `RefundController` | **Caught by the build, not by eye** — `ArchitectureIT` fails `mvn verify` until fixed |
| F9 | Hardcoded downstream settlement-notify URL | — | `RefundService` | Backlog |
| F10 | No `@ControllerAdvice` — inconsistent error shape vs. Spring's default | — | `RefundController` | Backlog |
| F11 | `RefundHealthIndicator` reports UP on `/actuator/health` without checking anything — a health endpoint that cannot fail | — | `RefundHealthIndicator.java` | Backlog |
| F12 | No `REFUNDS` privilege gate on the base refund path — a merchant with no privileges still gets a refund processed. Distinct from F6, which is specifically the `EXCESSIVE_REFUNDS` gate | Missing privilege gate | `RefundService.java` | Backlog |
| F13 | No currency-match validation against the original transaction | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F14 | No voided-target rejection — a VOIDED transaction can still be refunded | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F15 | No positive-input validation at all — a negative amount or a malformed currency is accepted and processed | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F16 | `ENABLE_REFUND_REQUESTS` and `SUPPORT_EXTENDED_REFUNDS` are declared in `RefundPrivilege` but never read anywhere — dead-weight privileges, not backed by any check | — | `RefundPrivilege.java` | Backlog |

A live trap in the quality gates, not the code: the unknown-dependency check is designed to
catch a hallucinated Maven coordinate (e.g. a "PAN masking library") if one is proposed during
Stage 4 remediation — the concrete version of Failure Mode 1 (Hallucination).

**A spec ambiguity worth naming, not silently resolved either way:** the spec pack's own "Out of
scope (Phase 1)" list states "Excessive refund is Phase 1.1" — yet its Business Rules, Error
Scenarios and Acceptance Criteria sections all describe `EXCESSIVE_REFUNDS` gating (F6) as active,
testable Phase 1 behavior. This document does not resolve which reading is correct; F6 is kept as
a registered finding because the spec pack's own ACs describe it as testable, but this is exactly
the kind of spec contradiction the lab itself teaches you to escalate rather than default on — see
`docs/SOURCE_TRACEABILITY.md`.

## Fidelity note

This lab's endpoint shapes now follow the real PGS contract: `POST
/card-payments/{card_payment_gateway_id}/refunds` (payment refund) and `POST
/card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds`
(capture refund). Offline versus online is selected by the request-body field
`wsApiSupport.refundAuthorization`, not by URL. The Void path (`POST
/card-payments/{card_payment_gateway_id}/void`) is a documented assumption rather than a
confirmed contract path — the spec pack never publishes a Void endpoint because Void flows are
out of scope.

What is still simulated, so nobody mistakes this for a production slice: CPC, LCS and DCF are
not in this process at all, and the settlement leg is downstream — the online refund path
authorizes and must not write settlement records. The H2 in-memory store is a lab fixture. And
`idempotencyKey` sits at the top level of the request as a documented assumption; the spec pack
states the 409 idempotency rule but never names the transport field.

The business rules and the seeded findings are faithful to the real spec pack. For a
decision-by-decision record of which parts come from the spec pack and which are labelled lab
assumptions, see [docs/SOURCE_TRACEABILITY.md](docs/SOURCE_TRACEABILITY.md).
