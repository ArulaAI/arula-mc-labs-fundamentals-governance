# Lab Action Guide — Finish the Refund

## Setup (5 minutes)

1. **JDK 17** — `java -version` should report 17 (Zulu recommended).
2. **Build state** — from the repo root:
   ```bash
   mvn validate && mvn test
   ```
   Both should succeed (`BUILD SUCCESS`). Now run:
   ```bash
   mvn verify
   ```
   This **should fail** — on exactly one thing, an ArchUnit layering-violation message. That's
   intended, not a broken lab: F8 is caught by the build itself, and you'll fix it in Stage 4.
   If `mvn verify` fails for any other reason, or passes cleanly, flag your facilitator before
   continuing.
3. **Harness loaded** — run `/lab`. Per the plugin's actual `/lab` command (0.2.0), it reads
   `.claude/lab.json`'s `lab`/`title`/`rubric` fields and prints the rubric's objectives, so
   expect it to report lab `1`, title "Finish the Refund", and the objective list from
   `.claude/lab.json` — not literally "F1, F2" (those remain the remediation targets for this
   lab, just not what `/lab` itself prints). Then confirm a journey event actually landed in
   `.claude/journey/` — not just that the command exited 0. `/hand-off`
   should also be listed. The `payments-guardrails` and `ai-use-policy` rules (from the
   `workbench` plugin) load automatically for every file — no separate install step beyond the
   plugin install itself.

## Commands and how to run them

| Command | Stage | What it does | Source |
|---|---|---|---|
| `/lab` | 0 | Reports lab number, title, rubric path, and objectives from `.claude/lab.json` | `workbench` plugin |
| `/hand-off` | every stage | Closes out the stage just finished; appends a structured entry to `docs/workflow-tracker.md` | this repo's own `.claude/commands/hand-off.md` -- the plugin also ships a `hand-off` command as of 0.2.0, but Claude Code resolves project-local commands first, so this repo's version is what actually runs |
| `/grade` | 6 | Runs `python3 .claude/scripts/grade_repo.py` (the plugin's own `lab-grader` does not support this rubric's check types -- see the rubric's own header comment) against `.claude/rubrics/finish-the-refund.rubric.yaml` and reports the grade card | this repo's own script |

**This lab is intentionally light on slash commands.** Stages 1 and 3 are direct prompts to
Claude Code, not wrapped commands — the point here is practicing unassisted comprehension and
test-authoring before later labs hand you `spec-craft`/`sdet-architect`. Stages 2 and 5 invoke
the `planner` subagent directly by name; Stage 4 invokes `pr-reviewer` directly by name. The
exact prompt text for every stage lives in `exercises/stage-<n>-<name>/instructions.md`; this
guide won't repeat it in full.

**If a command isn't recognized:** confirm the `workbench` plugin is actually installed — from a
local clone, not a marketplace (`claude plugin install ./arula-mc-labs-plugin/workbench`, see
README.md) — and that Claude Code is open at the repo root.

## The flow at a glance

| # | Stage | Min | Surface | Entry point |
|---|---|---|---|---|
| 0 | Ground: harness and the five failure modes | 18 | facilitator walkthrough | `exercises/stage-0-setup/` |
| 1 | Comprehend and register | 25 | direct prompt | `exercises/stage-1-comprehend-register/` |
| 2 | Plan | 12 | `planner` | `exercises/stage-2-plan/` |
| 3 | Prove it's broken | 15 | direct prompt | `exercises/stage-3-failing-tests/` |
| 4 | Remediate and build | 35 | edit, then `pr-reviewer` | `exercises/stage-4-remediation/` |
| 5 | Look ahead | 8 | `planner` (guide mode) | `exercises/stage-5-secure-future/` |
| 6 | Close | 7 | quality gates, `/hand-off`, `/grade` | `exercises/stage-6-governance/` |

**Total: 120 minutes.** Stage 4 is deliberately the largest block — it's where the sycophancy
trap fires and where the online refund path actually gets built. If your group is behind by the
20-minute mark of Stage 4, ask your facilitator for the `reference/` fallback rather than
rushing the fresh-context review step.

## Test model

Tests assert the **intended/secure** behavior, so they **fail before remediation** — that
failure is the evidence the gap is real. Do not write tests that lock in current unsafe or
incomplete behavior. At the Stage 3 checkpoint, `mvn test` shows exactly two new reds (F1, F2)
and `mvn verify` reports the same two — not three. `ArchitectureIT` (F8) is still genuinely red
underneath (it has been since a fresh clone), but Maven's default phase ordering means a single
`mvn verify` stops at the first failing phase and never re-reaches it once the two new tests are
also red. That's expected — see `exercises/stage-3-failing-tests/instructions.md` for how to
see F8's failure directly if you want to confirm it's still there.

## How the stages work

You are driving. The AI proposes; you decide. Every stage ends with `/hand-off`, and Stage 4's
two fixes each get their own fresh-context `pr-reviewer` pass — the failure mode that gate
exists to catch is *accepting a fix unread because you already believe it works*.

- **Stage 0 — Ground.** Facilitator frames: agents vs. skills vs. commands vs. rules, model
  tiers, why context degrades, why an agent reviewing its own work passes it, then the five
  failure modes, named. No code yet.
- **Stage 1 — Comprehend and register.** First, with your own eyes, no AI: run the app, submit
  the same refund twice (two records exist), open the log (authorization code in cleartext).
  Then prompt Claude Code for a file-by-file review — no fixes yet. Then triage what comes
  back: confirm real findings, reject decoys with a stated reason, rank by severity. Fill
  `RISK_REGISTER.md` yourself, one row per finding, all sixteen, including backlog.
- **Stage 2 — Plan.** `planner` turns your register into `docs/plans/plan.md`, Critical first,
  scoped to F1/F2 plus building `processOnlineRefund()`. Review it against the plugin's
  guardrail rules and the spec's own acceptance criteria before moving on. **Facilitator
  overhead running in parallel, not out of your budget:** the facilitator spot-checks 3 of your
  group's 14 register rows against the actual code (Stage 1→2 validation) — about 2 minutes,
  outside participant time.
- **Stage 3 — Prove it's broken.** Direct-prompt JUnit 5 tests asserting the intended behavior
  for F1 and F2. Checkpoint: `mvn test` shows exactly two new reds, everything else green — and
  `mvn verify` reports the same two, not three. `ArchitectureIT` (F8) is still genuinely red
  underneath, it just doesn't get re-reported in this run; see "Test model" above for why.
- **Stage 4 — Remediate and build.** Fix F1 with the smallest diff, validate, fresh-context
  `pr-reviewer`. Fix F2 the same way. `mvn verify` will still fail on ArchUnit until F8 is
  addressed — move the privilege-evaluation logic out of `RefundController` into
  `RefundService`; you don't have to hunt for this by eye, the build tells you. Then build
  `processOnlineRefund()`: honour `TOGGLE_ENABLE_ONLINE_REFUND`, null the authorization code
  from retrieval unless the return-authorization-data toggle is ON (online refunds only; the
  offline response body legitimately returns the auth code), do **not** write settlement
  records. Online-vs-offline is selected by the request body's `wsApiSupport.refundAuthorization`,
  not by a separate URL. **Watch the traps:** a PAN-masking-library request should fail the
  unknown-dependency check; an offer to write the settlement leg should be declined; a naive
  build that skips the `EXCESSIVE_REFUNDS` check reproduces F6 live. Update `RISK_REGISTER.md`
  and `FIXES.md`.
- **Stage 5 — Look ahead.** `planner` in guide mode writes `docs/secure-features-guide.md` —
  proactive controls grounded in this codebase (correlation IDs, tokenisation, config
  externalisation, deny-by-default validation, `@ControllerAdvice`). No code changes.
- **Stage 6 — Close.** Run `mvn verify` — quality gates including ArchUnit, plus sensitive-data
  and secret scans. Finish `SECURITY.md`, confirm every stage has a `/hand-off` entry in
  `docs/workflow-tracker.md` citing its actual artifact, then `python3 .claude/scripts/grade_repo.py`
  (see "Grade yourself" below for why, not the plugin's own `/grade`).

## Grade yourself

```bash
python3 .claude/scripts/grade_repo.py
```

**Do not use the plugin's own `/grade` command for this** — as of workbench plugin 0.2.0, its
`lab-grader` only supports four check types (`event_exists`, `event_contains`, `event_count_gte`,
`secret_scan_clean`) and does not understand this rubric's content-based checks
(`file_table_rows_gte`, `file_table_row_contains_all`, `all_of`, `seed_intact`, etc.) — running
`/grade` against `.claude/rubrics/finish-the-refund.rubric.yaml` will silently score those
criteria 0 regardless of what you did. `grade_repo.py` is the real, deterministic grader for this
rubric: the same journey/repo state always produces the same score. Writes
`.claude/journey/<session_id>-grade.json`.

Fallback: if the `workbench` plugin is not installed, run:

```bash
python3 .claude/scripts/grade_repo.py
```

This produces the same deterministic score against the same rubric file.

## Ground rules

- No remediation without its test failing first.
- Only F1 and F2 get fixed this pass (`.claude/lab.json` targets), plus building the online
  refund path. F8 gets fixed too, because the build won't go green otherwise. Everything else
  (F3, F4, F6, F7, F9, F10, F11, F12, F13, F14) stays `Open`, not silently resolved — and **F5 stays registered and
  escalated**, not defaulted, which is a different thing from ordinary backlog.
- `docs/FACILITATOR_KEY.md` is the answer key. Nothing currently blocks you from opening it
  early — that's on your own discipline, not a hook. Reading it before you've registered your
  own findings just means you're grading your own homework.
- Coverage as evidence, not a target: the optional bonus (`mvn verify`, then open
  `target/site/jacoco/index.html`) is for discussing which refund branches are proven versus the
  unverified backlog — no percentage to chase, no new code.

## See also

- [`AGENTS.md`](./AGENTS.md) — canonical rule, subagent, command, and hook reference
- [`README.md`](./README.md) — architecture note, prerequisites, generated artifacts
- [`docs/FACILITATOR_KEY.md`](./docs/FACILITATOR_KEY.md) — facilitator answer key (not for participants)
- [`docs/SOURCE_TRACEABILITY.md`](./docs/SOURCE_TRACEABILITY.md) — which design decisions come
  from the real PGS spec pack and which are labelled lab assumptions
- [`exercises/`](./exercises/) — per-stage instructions, exact prompts, and a predict-before-you-look hypothesis exercise
- [`specs/refunds-s2i-phase1.spec.md`](./specs/refunds-s2i-phase1.spec.md) — the spec this lab is built against
