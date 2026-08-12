# Lab 1: Fundamentals & Governance — `arula-mc-labs-fundamentals-governance`

A 2-hour, hands-on lab teaching payments engineers and senior analysts how to work with
Claude Code on secure, high-stakes payments code — with governance, an audit trail, and
fresh-context review built in from the first run, not bolted on afterward.

You'll work against a deliberately vulnerable Spring Boot card-authorization service,
find its seeded vulnerabilities yourself, plan and implement fixes under a fresh-context
review gate, and finish with a complete governance trail a reviewer who wasn't in the
room could trust.

## Prerequisites

- Java 21, Maven 3.9+
- Claude Code
- **`bash`** — every hook, command, and the grader are pure POSIX shell scripts. On
  Windows this means Git Bash (bundled with [Git for Windows](https://git-scm.com/download/win))
  or WSL; macOS and Linux ship `bash` already. Nothing else is required beyond that.
- No network access required at runtime — this lab is deliberately offline-capable (no
  outbound calls during grading or quality gates; standard Maven dependency resolution on
  first build is the only network activity, same as any Maven project)

## Getting started

```bash
git clone <this-repo> arula-mc-labs-fundamentals-governance
cd arula-mc-labs-fundamentals-governance
mvn compile
```

If `mvn compile` succeeds, you're ready for Stage 0. Open Claude Code in this directory —
the governance hooks, commands, and rules in `.claude/` activate automatically; there is no
separate install step. Run `/lab` to confirm the lab contract loaded.

**The participant-facing walkthrough is [`LAB_ACTION_GUIDE.md`](LAB_ACTION_GUIDE.md)** —
exact stage-by-stage prompts, minute budgets, and checkpoints. This README covers
architecture and setup; `exercises/stage-<n>-<name>/` gives each stage a predict-before-
you-look `hypothesis.md` companion, per the spec → hypothesis → confidence discipline this
lab also practices.

## The 7 stages

| # | Stage | Min | You produce |
|---|---|---|---|
| 0 | Context and the five failure modes | 15 | shared understanding, confirmed harness |
| 1 | Comprehend & Register | 25 | `RISK_REGISTER.md` — every finding you identify |
| 2 | Plan | 12 | `docs/plans/plan.md` — ordered remediation steps (via `planner`) |
| 3 | Failing security tests (top 2) | 18 | `SecurityTest.java` — two reds, before any fix |
| 4 | Remediation (top 2 only) | 25 | V1 + V2 fixed, `FIXES.md`, fresh-context `pr-reviewer` |
| 5 | Secure Future | 10 | `docs/secure-features-guide.md` — proactive controls, no code |
| 6 | Governance | 15 | `docs/workflow-tracker.md` complete, `SECURITY.md` written, graded |

See [AGENTS.md](AGENTS.md) for the rules, subagents, and commands that apply throughout,
and `.claude/rules/ai-use-policy.md` for what "governed" actually means in this lab.

## What you're looking for

Three vulnerabilities are seeded in the service on purpose. Find them yourself in Stage 1
— don't peek at `AGENTS.md`'s finding list or `docs/FACILITATOR_KEY.md` before you've
registered your own findings, or you'll be grading your own homework. In short:
cardholder-data exposure, an authorization fail-open, and an idempotency race condition.
**Only the first two (V1, V2) get remediated this pass** — see `.claude/lab.json`. A
fourth trap — a hallucinated dependency — waits in the quality gates, not the source code.

## Generated artifacts (not committed)

- `.claude/journey/<session_id>.jsonl` — append-only, redacted event log of the session
- `.claude/quality-gates-latest.json` — most recent quality-gate run's per-gate status
- `.claude/.pom-dependency-baseline.txt` — first-run snapshot used by the unknown-dependency gate

## Grading

```bash
bash .claude/hooks/lab-grader.sh . --run-id <your-session-id> --format both
```

Or just run `/grade`. Grades against `.claude/fundamentals.rubric.yaml` (7 weighted
criteria mapped directly to this lab's acceptance checklist, deterministic — the same
journey file always produces the same score). Writes
`.claude/journey/<run-id>.grade.json`.

## Architecture note

This repo is a **plain, self-contained Claude Code repository** — no plugin install step,
no external primitive-vendoring mechanism. That's a deliberate choice, not an oversight:
this lab only needs to support Claude Code (not a second harness), so the dual-harness
`.forge/manifest.yaml` + `forge-sync` pattern used by some other labs in this program adds
indirection this one doesn't need. Everything under `.claude/` is committed directly and
active by default.

Arula is separately building a `workbench` plugin that will drop directly into this and
other labs, and will be the repository basis for **Lab 4** ("extend the workbench"). This
repo's hand-authored `.claude/agents/`, `.claude/rules/`, and `.claude/hooks/` cover the
same governance surface in the meantime and were not built to be thrown away — expect them
to coexist with or feed into that plugin once it lands, not be silently replaced.

## Known limitations

- The `subagent_start`/`subagent_stop` journey events read `agent_type`/`subagent_type`
  from the hook payload defensively (the exact field name wasn't confirmed against a live
  captured payload at build time). Verify against a real session before grading depends
  heavily on subagent-count criteria.
- Quality gates are intentionally **non-blocking** (always exit 0) — they report to stdout
  and the journey log; Stage 6's governance review is the actual gate, not the script.
- The unknown-dependency gate is diff-based, not a real registry lookup (this lab is
  offline by design) — it catches new coordinates since the first baseline snapshot, not
  provably-fake ones.
