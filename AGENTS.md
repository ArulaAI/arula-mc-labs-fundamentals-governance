# AGENTS.md — arula-mc-labs-fundamentals-governance

This file is the canonical instruction set for Claude Code (and any future harness) working
in this repository. `CLAUDE.md` imports it directly.

## What this repo is

**Lab 1: Fundamentals & Governance** — a deliberately vulnerable Spring Boot card-authorization
service, used to teach governed, audited, fresh-context-reviewed AI-assisted secure
engineering. Participant-facing flow lives in [LAB_ACTION_GUIDE.md](LAB_ACTION_GUIDE.md);
architecture/prerequisites in [README.md](README.md); facilitator-only answer key in
[docs/FACILITATOR_KEY.md](docs/FACILITATOR_KEY.md).

## Commands

| Command | Purpose |
|---|---|
| [`/lab`](.claude/commands/lab.md) | Reports lab id, remediation targets, rubric, and time budget from `.claude/lab.json` |
| [`/hand-off`](.claude/commands/hand-off.md) | Closes out the current stage, appends to `docs/workflow-tracker.md` |
| [`/grade`](.claude/commands/grade.md) | Runs `.claude/hooks/lab-grader.sh` against `.claude/fundamentals.rubric.yaml` |

`.claude/lab.json` is the machine-readable lab contract: `{"id":"fundamentals-governance",
"targets":["V1","V2"],"rubric":"fundamentals.rubric.yaml","minutes":120}`. **Only V1 and V2
are remediated this pass** — V3 stays a registered, `Open` finding, not a remediation
target. Do not treat `.claude/lab.json`'s `targets` list as optional guidance; it's the
enforced scope for Stage 4.

## Rules that apply to every change in this repo

Read these before making any change — they are not optional context, they are the review bar:

- [`.claude/rules/payments-guardrails.md`](.claude/rules/payments-guardrails.md) — cardholder-data handling, fail-closed authorization, idempotency, no invented dependencies, smallest diff, backlog discipline
- [`.claude/rules/ai-use-policy.md`](.claude/rules/ai-use-policy.md) — human-in-the-loop, fresh-context review, logged assumptions, no scope creep, full auditability, synthetic data only
- [`.claude/rules/coding-standards.md`](.claude/rules/coding-standards.md) — Java/Spring Boot baseline (scoped to `**/*.java`, `pom.xml` via frontmatter)
- [`.claude/rules/spec-template.md`](.claude/rules/spec-template.md) — required structure for `docs/plans/plan.md` and `docs/secure-features-guide.md`

## Subagents

Three subagents run in **fresh context** — they never inherit the reasoning or self-confidence
of the session that did the work, which is the whole point (see `ai-use-policy.md` §2):

| Agent | Purpose | Tools |
|---|---|---|
| [`planner`](.claude/agents/planner.md) | Turns `RISK_REGISTER.md` into an ordered `docs/plans/plan.md`, or produces `docs/secure-features-guide.md` | Read, Grep, Glob, Write |
| [`code-to-spec-validator`](.claude/agents/code-to-spec-validator.md) | Validates a plan against the template, or a change against a finding's acceptance criteria | Read, Grep, Glob |
| [`pr-reviewer`](.claude/agents/pr-reviewer.md) | Skeptical, read-only review of a diff against coding standards — cannot Write or Edit | Read, Grep, Glob |

## Automatic governance (hooks)

Wired in `.claude/settings.json`, always active (no per-repo opt-in — this repo commits its
own hooks directly):

- **Journey recording** (`.claude/hooks/journey-record.sh`) — appends a redacted, hashed event
  to `.claude/journey/<session_id>.jsonl` on every tool use, prompt, and session/subagent
  boundary. Never stores raw prompt/tool text — only a SHA-256 hash and a masked preview.
- **Quality gates** (`.claude/hooks/quality-gates.sh`) — fires after every `mvn test`/`mvn
  verify`, runs 4 non-blocking gates (cardholder-data scan, secret scan, coverage report,
  unknown-dependency diff), writes `.claude/quality-gates-latest.json`.
- **Lab grader** (`.claude/hooks/lab-grader.sh`, wired via `/grade`) — against
  `.claude/fundamentals.rubric.yaml`; deterministic, same journey file always yields the
  same score.

## The seeded findings

Three vulnerabilities are seeded in the card-auth service on purpose, for participants to
find in Stage 1 — do not "fix" them ahead of time or point them out unprompted. Full detail
(OWASP mapping, smallest-diff outline, exact test assertions) is in
[docs/FACILITATOR_KEY.md](docs/FACILITATOR_KEY.md), facilitator-only.

- **V1 — Cardholder-data exposure** (Critical, remediation target): PAN/CVV logged and
  returned in responses (`AuthService`, `AuthController`, `InMemorySessionStore`)
- **V2 — Authorization fail-open** (Critical, remediation target): missing/blank bearer
  token resolves to `"admin"` (`AuthService.resolveRole`), and admin endpoints never check
  the resolved role (`AdminController`)
- **V3 — Idempotency race condition** (High, **registered but not remediated this pass**):
  `InMemorySessionStore.createHold` does an unsynchronized check-then-act on
  `idempotencyKey`. This is a real, unfixed finding — distinct from the hygiene backlog
  below — left `Open` in `RISK_REGISTER.md` by design (see `.claude/lab.json` `targets`).

Plus a documented hygiene backlog, never in scope to fix in this lab: no per-PAN/merchant
rate limiting, weak PAN validation (`PanTools.isLuhnValid` unused), naive expiry parsing,
verbose stack traces, no audit record for admin actions.

A fourth trap lives in the quality gates, not the code: the unknown-dependency gate is
designed to catch a hallucinated Maven coordinate (e.g. `com.mastercard:pan-vault`) if one
is proposed during remediation — this is FM1 (Hallucinated Dependencies) made concrete.
