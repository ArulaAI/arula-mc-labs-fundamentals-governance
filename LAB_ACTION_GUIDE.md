# Lab Action Guide — Fundamentals & Governance

## Setup (5 minutes)

1. **JDK 21** — `java -version` should report 21.
2. **Build green** — from the repo root:
   ```bash
   mvn validate && mvn test && mvn verify
   ```
   You should see `BUILD SUCCESS`. This is the clean baseline — the vulnerabilities are
   real code, and the suite passes *with them present*. Fixing two of them is your job.
3. **Verify zero network** — this lab makes no outbound calls. If you want to prove it, run
   the suite with your network disabled; it still passes.
4. **Harness loaded** — run `/lab`. It should report lab id `fundamentals-governance`,
   targets `V1, V2`, and a 120-minute budget, read straight from `.claude/lab.json`.
   `/hand-off` and `/grade` should also be listed. The `payments-guardrails` and
   `ai-use-policy` rules load automatically for every file — no separate install step.

## Commands and how to run them

| Command | Stage | What it does |
|---|---|---|
| `/lab` | 0 | Reports lab id, remediation targets, rubric, and time budget from `.claude/lab.json` |
| `/hand-off` | every stage | Closes out the stage just finished; appends a structured entry to `docs/workflow-tracker.md` |
| `/grade` | 6 | Runs `.claude/hooks/lab-grader.sh` against `.claude/fundamentals.rubric.yaml` and reports the grade card |

**This lab is intentionally light on slash commands.** Stages 1 and 3 are direct prompts to
Claude Code, not wrapped commands — the point here is practicing unassisted comprehension
and test-authoring before later labs hand you `spec-craft`/`sdet-architect`. Stages 2 and 4
invoke the `planner`, `code-to-spec-validator`, and `pr-reviewer` **subagents** directly, by
name, in your prompt — there's no `/plan` or `/review` wrapper. The exact prompt text for
every stage lives in `exercises/stage-<n>-<name>/instructions.md`; this guide won't repeat
it in full.

**If a command isn't recognized:** confirm Claude Code is open at the repo root — `.claude/`
must be loaded. There's nothing to install or sync.

## The flow at a glance

| # | Stage | Min | Surface | Entry point |
|---|---|---|---|---|
| 0 | Context and the five failure modes | 15 | facilitator walkthrough | `exercises/stage-0-setup/` |
| 1 | Comprehend and register | 25 | direct prompt | `exercises/stage-1-comprehend-register/` |
| 2 | Plan | 12 | `planner`, `code-to-spec-validator` | `exercises/stage-2-plan/` |
| 3 | Failing security tests (top 2) | 18 | direct prompt | `exercises/stage-3-failing-tests/` |
| 4 | Remediation (top 2 only) | 25 | edit, then `pr-reviewer` | `exercises/stage-4-remediation/` |
| 5 | Secure-future guide | 10 | `planner` | `exercises/stage-5-secure-future/` |
| 6 | Governance validation and reporting | 15 | quality gates, `/hand-off`, `/grade` | `exercises/stage-6-governance/` |

**Total: 120 minutes.**

## Test model

Security tests assert the **secure** behavior, so they **fail before remediation** — that
failure is the evidence the vulnerability is real. Remediation turns them green. Do not
write tests that lock in the current unsafe behavior. At the Stage 3 checkpoint, both
slices (V1 and V2 — 2-3 test methods each, so 4-6 individual failures total) are expected
to be red, and everything else stays green. "Two reds" means two failing *slices*, not a
literal count of 2 JUnit methods.

## How the stages work

You are driving. The AI proposes; you decide. Every stage ends with `/hand-off`, and
Stage 4's two fixes each get their own fresh-context `pr-reviewer` pass — the failure mode
that gate exists to catch is *accepting a fix unread because you already believe it works*.

- **Stage 0 — Context.** Facilitator frames the five failure modes: hallucination, correctly
  solving the wrong problem, incorrectly solving the right problem, self-congratulation in
  review, invented dependencies. No code yet.
- **Stage 1 — Comprehend & register.** Run the app, observe the vulnerable behavior
  firsthand, then prompt Claude Code to review the service. **Triage before you register:**
  the finding is yours to confirm, not Claude's to hand you. Fill `RISK_REGISTER.md`
  yourself, one row per finding — including backlog items you don't plan to fix.
- **Stage 2 — Plan.** `planner` turns your register into `docs/plans/plan.md`, Critical
  first. `code-to-spec-validator` checks it against the guardrail and coding-standards rules
  before you move on — close any gaps it reports.
- **Stage 3 — Failing tests.** Direct-prompt two slices of JUnit 5 + MockMvc tests, one per
  in-scope finding. Checkpoint: `mvn test` shows exactly two reds, everything else green.
- **Stage 4 — Remediate, top 2 only.** Fix V1 and V2 with the smallest diff each, run
  `code-to-spec-validator` then `pr-reviewer` per slice. **Watch the traps:** a fix that
  masks the PAN in the response but still logs it is "correctly solving the wrong problem" —
  `code-to-spec-validator` should catch it. Everything else (V3, the hygiene backlog) stays
  `Open` — untouched, not silently resolved.
- **Stage 5 — Secure future.** `planner` writes `docs/secure-features-guide.md` — proactive
  controls grounded in this specific codebase, no code changes.
- **Stage 6 — Governance.** Ask Claude Code to run `mvn verify` — the quality gates
  (cardholder-data scan, secret scan, coverage report, unknown-dependency check) fire as a
  hook on Claude Code's own tool call, so they only trigger when Claude Code runs the
  command, not when you type it in a separate terminal window. Finish `SECURITY.md`,
  confirm every stage has a `/hand-off` entry in `docs/workflow-tracker.md`, then `/grade`.

## Grade yourself

```bash
/grade
```

or directly:

```bash
bash .claude/hooks/lab-grader.sh . --run-id <your-session-id> --format both
```

Deterministic — the same journey file always produces the same score. Writes
`.claude/journey/<run-id>.grade.json`.

## Ground rules

- No remediation without its security test failing first.
- Only V1 and V2 get fixed this pass (`.claude/lab.json` `targets`) — V3 and the hygiene
  backlog stay `Open`, not silently resolved, even if you notice something else worth fixing.
- `docs/FACILITATOR_KEY.md` is the answer key. Nothing currently blocks you from opening it
  early — that's on your own discipline, not a hook. Reading it before you've registered
  your own findings just means you're grading your own homework.
- Coverage as evidence, not a target: the optional bonus (`mvn verify`, then open
  `target/site/jacoco/index.html`) is for discussing which authorization branches are
  proven versus the unverified backlog — no percentage to chase, no new code.

## See also

- [`AGENTS.md`](./AGENTS.md) — canonical rule, subagent, and command reference
- [`README.md`](./README.md) — architecture note, prerequisites, generated artifacts
- [`docs/FACILITATOR_KEY.md`](./docs/FACILITATOR_KEY.md) — facilitator answer key (not for participants)
- [`exercises/`](./exercises/) — per-stage instructions, exact prompts, and a predict-before-you-look hypothesis exercise
