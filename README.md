# Lab 1: Finish the Refund — `arula-mc-labs-fundamentals-governance`

A 2-hour, hands-on lab teaching payments engineers how to work with Claude Code on secure,
high-stakes payments code — with governance, an audit trail, and fresh-context review built in
from the first run, not bolted on afterward.

You'll work against a real Mastercard PGS backlog thread (`G1190-3291`, Support Refunds for S2I
transactions, Phase 1): a half-built Refunds service whose offline path passes every test while
carrying five real governance failures, and whose online path is still an
`UnsupportedOperationException` you finish this sprint. Find the seeded findings yourself, plan
and implement fixes under a fresh-context review gate, and finish with a complete governance
trail a reviewer who wasn't in the room could trust.

## Prerequisites

- JDK 17 (Zulu recommended), Maven 3.9+
- Claude Code, **latest version** — this lab depends on the `workbench` plugin, whose own
  `docs/ARCHITECTURE.md` requires 2.1.177+ for component auto-discovery. No floor to manage
  below that; just stay current.
- The `workbench` plugin installed from the private marketplace:
  `claude plugin install workbench@<marketplace>` (confirm the exact marketplace name with
  whoever hosts it before session day)
- `~/.m2` pre-warmed before session day — this service makes no outbound network calls at
  *runtime*, but the first `mvn verify` on a cold `~/.m2` resolves dependencies over the network
  like any Maven build

## Getting started

```bash
git clone <this-repo> lab-refunds-s2i
cd lab-refunds-s2i
mvn compile
```

If `mvn compile` succeeds, you're ready for Stage 0. Open Claude Code in this directory — with
the `workbench` plugin installed, its rules, agents, hooks, and commands activate automatically;
there is no separate per-repo install step beyond the plugin install itself. Run `/lab` to
confirm the lab contract loaded, and confirm a journey event actually landed in
`.claude/journey/` — not just that the command exited 0. On Windows, this is where a silent
bash/PATH issue would otherwise surface at Stage 6 instead of now.

**The participant-facing walkthrough is [`LAB_ACTION_GUIDE.md`](LAB_ACTION_GUIDE.md)** — exact
stage-by-stage prompts, minute budgets, and checkpoints. This README covers architecture and
setup; `exercises/stage-<n>-<name>/` gives each stage a predict-before-you-look `hypothesis.md`
companion, per the spec → hypothesis → confidence discipline this lab also practices.

## The 7 stages

| # | Stage | Min | You produce |
|---|---|---|---|
| 0 | Context and the five failure modes | 18 | shared understanding, confirmed harness |
| 1 | Comprehend & Register | 25 | `RISK_REGISTER.md` — every finding you identify, all fourteen |
| 2 | Plan | 12 | `docs/plans/plan.md` — ordered remediation steps (via `planner`) |
| 3 | Prove it's broken | 15 | two failing test slices, before any fix |
| 4 | Remediate and build | 35 | F1 + F2 fixed, `processOnlineRefund()` built, `FIXES.md`, fresh-context `pr-reviewer` |
| 5 | Look ahead | 8 | `docs/secure-features-guide.md` — proactive controls, no code |
| 6 | Close | 7 | `docs/workflow-tracker.md` complete, `SECURITY.md` written, graded |

See [AGENTS.md](AGENTS.md) for the rules, subagents, commands, and hooks that apply throughout —
all provided by the `workbench` plugin except `/hand-off`, which is this lab's own.

## What you're looking for

Fourteen findings are seeded on purpose, every one traceable to `pgs-lab-spec-pack.md`. Find them
yourself in Stage 1 — don't peek at `AGENTS.md`'s finding list or `docs/FACILITATOR_KEY.md`
before you've registered your own findings, or you'll be grading your own homework. In short:
sensitive data logged in cleartext, a missing idempotency check, an out-of-scope Void endpoint
that shouldn't exist, a hallucinated pre-risk-assessment dependency, and a genuinely undefined
business rule (`REFUND_EXPIRY`'s window) that the correct move is to escalate, not default. Also
a health check that reports UP without checking anything, and business rules from the spec
(privilege gate, currency match, voided-target rejection) that the shipped path never implements.
**Only F1 and F2 get remediated this pass, plus building the online refund path** — see
`.claude/lab.json`. F8 (a layering violation) is caught by the build itself, not by eye.

## Generated artifacts (not committed)

- `.claude/journey/<session_id>.jsonl` — append-only, redacted event log of the session
  (`WORKBENCH_JOURNEY_DIR` is set to `.claude/journey` in `.claude/settings.json`)
- `target/` — standard Maven build output

## Grading

```bash
/grade
```

Runs the plugin's `lab-grader` skill against `.claude/rubrics/finish-the-refund.rubric.yaml`
(deterministic — the same journey file always produces the same score; see the rubric's own
header comment for the exact criteria count, since it changes as the rubric is hardened and a
number here would just go stale). Content checks (not just existence checks) are real here:
registering a finding with a placeholder instead of the actual affected file, or pasting one
hand-off template seven times, will not score by themselves — though see
`docs/FACILITATOR_KEY.md`'s mandatory Stage 1→2 spot-check for the one gap the rubric cannot
close on its own.

Fallback: if the `workbench` plugin is not installed, run the same deterministic grader locally:

```bash
python3 .claude/scripts/grade_repo.py
```

This produces the same score against the same rubric file.

## Architecture note

This repo depends on the real `workbench` plugin
([`ArulaAI/arula-mc-labs-plugin`](https://github.com/ArulaAI/arula-mc-labs-plugin)) for its
rules, agents, hooks, and most commands. Repo-local components are forbidden only where they
would duplicate plugin-provided functionality. Only `/hand-off` is repo-local
(`.claude/commands/hand-off.md`), because the plugin has no equivalent — it ships
`/journey start|stop|export`, a different concept (session-wide capture, not a per-stage
narrative hand-off). `.claude/hooks/gate_guard.py` is an explicit, justified exception: the
plugin ships no blocking equivalent (`quality_gates.py` is reporting-only), so a local copy does
not drift out of sync.

Two capabilities this lab needs do not exist in the plugin's `0.1.0`, so both are **implemented
locally as a stopgap** rather than tracked and waited on:

- `.claude/hooks/gate_guard.py` — the `PreToolUse` hook described above. Run
  `python3 .claude/hooks/gate_guard.py --self-test` to confirm it still blocks every bypass
  class it was written for (absolute paths, `../` traversal, case-variant paths on a
  case-insensitive filesystem, and `NotebookEdit`'s distinct `notebook_path` key).
- `.claude/scripts/grade_repo.py` — a deterministic grader implementing the content checks this
  repo's rubric depends on: `file_contains`, `file_contains_all`, `file_row_contains_all`,
  `file_table_row_contains_all`, `file_table_rows_gte`, `file_contains_all_uncommented`,
  `file_sections_nonempty`, `file_secret_scan_clean`, `seed_intact` and `all_of`. Same rubric
  file, same score, no plugin required. `--self-test` grades synthetic empty / populated /
  crammed / F5-defaulted repos to prove the rubric actually discriminates between them.

A third, `.claude/scripts/anti_gaming_check.py`, has no plugin counterpart planned: it
re-injects the seeded F1 leak into a throwaway copy and re-runs the participant's own F1 test,
which is the only way to tell a real test from one that asserts nothing. Facilitator tool, not
part of the score — see `docs/FACILITATOR_KEY.md`.

Provenance for every design decision in this lab — what came from the real PGS spec pack and
what is a labelled lab assumption — is recorded in
[`docs/SOURCE_TRACEABILITY.md`](docs/SOURCE_TRACEABILITY.md).

## Known limitations

- Stack version pins in `pom.xml` (Spring Boot 3.5.14, Log4j2 2.25.4, ArchUnit 1.2.1, JaCoCo
  0.8.12) are InRhythm defaults for lab reproducibility, not yet independently confirmed against
  PGS's actual pinned versions — see the inline comment in `pom.xml`.
- This lab's endpoint shapes follow the real PGS contract: `POST
  /card-payments/{card_payment_gateway_id}/refunds` and `POST
  /card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds`.
  The Void path is a documented assumption rather than a confirmed contract path, since the spec
  pack never publishes a Void endpoint. See `specs/refunds-s2i-phase1.spec.md` for the full
  contract details.
- `.claude/rubrics/finish-the-refund.rubric.yaml`'s own header comment documents a real DSL
  limitation: it cannot mechanically prove a build's pass/fail result (e.g. "`mvn verify` went
  green") from the journey log alone, since `journey_record.py` doesn't capture tool exit codes.
  That's the facilitator's live Stage-4 spot-check to cover, not a rubric gap to paper over.
