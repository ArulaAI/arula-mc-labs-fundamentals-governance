# Lab 1 — Finish the Refund

**Thread:** `G1190-3291` Support Refunds for S2I transactions, Phase 1 (Processing domain) ·
**Level:** 100 → 200 · **Duration:** 120 minutes · **Topology:** one repo, the real PGS contract

---

## The scenario

A squad member got the offline refund path working — tests green, build clean — then got pulled
onto a Sev-2 before finishing the harder case. The online path is still an
`UnsupportedOperationException`. You inherit the file. It merges Thursday. Nothing in the diff
looks wrong — that's exactly the problem: this one file carries sixteen real governance findings,
traced to the real PGS spec pack, that a passing build will never show you.

**Your role:** the engineer finishing the inherited file, with an AI assistant as your pair.

**What you are building:** two findings fixed by hand under fresh-context review, one finding
caught mechanically by the build (F8's layering violation — you don't hunt for it, `mvn verify`
tells you), and `processOnlineRefund()` built from scratch to spec — the feature toggle honoured,
the authorization code correctly nulled on retrieval, no settlement record written.

**This is also the first lab in the series**, so Stage 0 below walks you through installing the
`workbench` plugin itself — every later lab assumes that part is already done.

---

## Setup

### Prerequisites

- JDK 17 (Zulu recommended), Maven 3.9+
- Claude Code — teach on whatever version you actually have; no upgrade required. Live-tested
  this pass on both 2.1.108 and 2.1.234: the plugin installs, lists as enabled, and validates
  cleanly on both.
- The `workbench` plugin — installed in Stage 0, not before. If you want it ready ahead of time
  anyway, the two commands are in Stage 0 below.

### Preflight (before the session starts)

1. `java -version` → 17.x (or 21.x compiling to target 17) · `mvn -version` → 3.9+
2. Pre-warm the Maven cache once per machine: `mvn -q -o dependency:go-offline` — this service
   makes no outbound calls at *runtime*, but a cold `~/.m2` resolves dependencies over the
   network on the first build like any Maven project.
3. From the repo root:
   ```bash
   mvn validate && mvn test
   ```
   Both should succeed (`BUILD SUCCESS`). Now run:
   ```bash
   mvn verify
   ```
   This **should fail** — on exactly one thing, an ArchUnit layering-violation message. That's
   intended, not a broken lab: F8 is caught by the build itself, and you fix it in Stage 4. If
   `mvn verify` fails for any other reason, or passes cleanly, flag your facilitator before
   continuing.

---

## What is already true when you start

- `mvn test` is **green**.
- The offline refund path works.
- The online path throws `UnsupportedOperationException` — genuinely unbuilt.
- `mvn verify` is **red**, on exactly one ArchUnit message (F8).
- Sixteen findings are seeded in this one file; none are fixed yet.

---

## Stage 0 — Ground: install the harness, meet the five failure modes (18 min)

**Objective.** A confirmed-working plugin install and shared vocabulary before anyone touches a
keyboard. An ungrounded room diverges within ten minutes — and since this is the first lab, "the
harness" includes actually installing it, not just confirming it.

**Action.**

1. Install the plugin, live, together — a small **private** marketplace that ships in the plugin
   repo itself, not a public registry:
   ```bash
   claude plugin marketplace add https://github.com/ArulaAI/arula-mc-labs-plugin
   claude plugin install workbench@mastercard-workbench
   ```
   No clone needed just for this — `marketplace add` fetches the repo directly. Confirmed working
   identically on 2.1.108 and 2.1.234 this pass. **On 2.1.108, omit `-y`** — that flag doesn't
   exist there yet; the plain command completes fine without it.
2. Facilitator walks the room through: agents vs. skills vs. commands vs. rules (what each piece
   of the `workbench` plugin actually is); model tiers and when to use which; why context
   degrades over a long session; what determinism means when the underlying model is
   probabilistic; why an agent reviewing its own work tends to pass it.
3. The five failure modes, named explicitly — you'll meet all five, firsthand, this lab:
   - **Hallucination** — inventing behavior, fields, or dependencies the spec never mentions
   - **Correctly solving the wrong problem** — building something real and well-engineered that
     was never in scope
   - **Incorrectly solving the right problem** — the right feature, built with a gap the spec's
     edge cases exposed
   - **Sycophancy** — an agent (or a person) reviewing its own work and approving it
   - **Invented dependencies** — adding a call to a service, library, or check that doesn't
     exist on this path

**Commands.** `/lab` → confirm it reports lab id `finish-the-refund`, targets `F1, F2`, and a
120-minute budget. Then **confirm a journey event actually landed** in `.claude/journey/` — open
the directory, don't just trust the command's exit code. On Windows this is where a silent
bash/PATH issue would otherwise surface at Stage 6 instead of now.

**Human gate.** Room can name all five failure modes without looking them up; `/lab` reports the
correct id/targets/budget; a journey event file exists.

**Failure / recovery.** `claude plugin marketplace add` fails or times out → check network access
to GitHub before anything else; retry once. `/lab` not recognized after a successful install →
confirm Claude Code is open at the repo root, not a parent or child directory. No journey event
despite `/lab` working → the plugin installed but its hooks aren't wired for this session; flag
your facilitator, don't proceed into Stage 1 ungraded.

**Close the stage.** `/hand-off` — cite the confirmed harness state (plugin installed, journey
event present, plugin commands listed) as this stage's artifact.

**Invariant.** Plugin installed and validated; harness live; room can name the five failure modes.

---

## Stage 1 — Comprehend and register (25 min)

**Objective.** A registered, prioritized `RISK_REGISTER.md` with all sixteen findings — not just
the ones you plan to fix.

**Action.**

1. **First, with your own eyes, no AI.**
   - Start the app: `mvn spring-boot:run`. Submit the same
     `POST /card-payments/cpg-1001/refunds` request twice with the same `idempotencyKey` — two
     records exist instead of one 409.
   - Open the application log — the authorization code appears in cleartext.
   - Try `POST /card-payments/cpg-1001/void` — it answers, and per `specs/OUT_OF_SCOPE.md`, it
     shouldn't exist at all.
2. Read `specs/refunds-s2i-phase1.spec.md` and `specs/OUT_OF_SCOPE.md` in full.
3. **Then** direct-prompt Claude Code:
   > "Review these files together: `RefundController.java`, `RefundService.java`,
   > `RefundPrivilege.java`, `PreRiskAssessmentClient.java`, `RefundRecordDao.java`,
   > `RefundHealthIndicator.java`. For each file return a table: file | responsibility | key
   > dependencies | hidden side effects. Do not suggest fixes. Do not create the risk register
   > yet."
4. **Triage what comes back.** Confirm the real findings, reject anything plausible-but-out-of-
   scope with a stated reason (a couple of decoys are seeded on purpose), rank by severity.
5. Fill `RISK_REGISTER.md`, one row per finding, all sixteen, including backlog. Cite the actual
   affected file for each row — a placeholder won't score.
6. **F5 is deliberately hard.** Look specifically at `RefundPrivilege.java` and the spec's
   privilege section. Don't move on until your group has explicitly decided whether it found F5
   or not — if not, your facilitator reveals it at the debrief.

**Artifact.** `RISK_REGISTER.md`, all sixteen rows.

**Human gate.** At least two findings found unaided, before any AI involvement; at least two
decoys explicitly rejected with a stated reason; F5's status explicit either way.

**Failure / recovery.** `docs/FACILITATOR_KEY.md` is the answer key — nothing blocks you from
opening it early, that's on your own discipline, not a hook. Opening it before you've registered
your own findings just means you're grading your own homework.

**Close the stage.** `/hand-off` — cite `RISK_REGISTER.md` as this stage's artifact.

**Invariant.** All sixteen findings registered, each citing a real affected file; F5's status
stated explicitly, not silently skipped.

---

## Stage 2 — Plan (12 min)

**Objective.** An ordered remediation plan, Critical first, scoped to exactly F1, F2, and building
`processOnlineRefund()` — nothing else.

**Surface.** The `planner` subagent, invoked directly by name.

**Prompt.**

> "Using `RISK_REGISTER.md` and `specs/refunds-s2i-phase1.spec.md`, produce a remediation plan
> scoped to F1 and F2 plus building `processOnlineRefund()`. For each step: target file(s),
> one-line fix or build task, expected post-fix state, success criterion. Critical first. Save to
> `docs/plans/plan.md`."

**Artifact.** `docs/plans/plan.md`.

**Human gate.** Review the plan yourself against `payments-guardrails` and the spec's own
acceptance criteria before moving on. Close any gap you find — don't accept a plan that silently
expands scope (a step touching F3–F14) or silently narrows it (no step for the online-path
build).

**Failure / recovery.** **Facilitator overhead running in parallel, not out of your budget:** the
facilitator spot-checks 3 of your group's 14 register rows against the actual code — about 2
minutes, outside participant time.

**Close the stage.** `/hand-off` — cite `docs/plans/plan.md` as this stage's artifact.

**Invariant.** Plan exists, Critical-severity steps first; every step maps to F1, F2, or the
online-path build, each naming its target file(s) and a concrete success criterion.

---

## Stage 3 — Prove it's broken (15 min)

**Objective.** Two new red test slices, proving F1 and F2 are real — before touching any
production code.

**Prompt.**

> "Write JUnit 5 tests asserting the INTENDED behavior:
>
> - F1, LOGS ONLY: no authorization code appears in RefundService's log output — neither the
>   INFO success line nor the ERROR line in the catch block — for an offline refund. Use Spring
>   Boot's `OutputCaptureExtension` (already available via `spring-boot-starter-test`) with a
>   `CapturedOutput` parameter; do not add a new dependency for this. Do NOT assert the offline
>   RESPONSE body is scrubbed — the spec scopes authorization-code nulling to ONLINE refund
>   retrieval only, so the offline response legitimately still carries it. Assert it is still
>   present, to pin the scope of the fix.
> - F2: a retried refund with the same idempotencyKey returns a decline/409 and creates no
>   second record.
>
> Build request objects with `com.mc.pgs.refunds.support.RefundRequestFixtures` — do not
> hand-assemble the nested `amounts`/`merchantOrder`/`wsApiSupport` structure. Deterministic
> tests, follow existing conventions. Do not modify production code."

**Why F1's slice is logs-only.** A test asserting the offline response is scrubbed would still be
red after a completely correct fix — that's not proving it's broken, it's proving the test wrong.
If Claude Code volunteers that assertion anyway, notice it: generalising a real rule past its
stated scope is exactly the failure mode this stage exists to make visible.

**Artifacts.** Two new test slices.

**Observable.** `mvn test` shows exactly the two new reds, everything else green. `mvn verify`
reports the same two, not three — Maven stops at the first failing phase, so a plain invocation
never reaches the later `verify`/failsafe phase where `ArchitectureIT` (F8) lives once earlier
tests are red. F8's red is real and unchanged, just not re-reported in this run. To see all three
together: `mvn verify -Dmaven.test.failure.ignore=true` (the final line will say `BUILD SUCCESS`
even though three things failed — that's what "ignore" means to Maven; read the `[ERROR]` blocks,
not the last line).

**Human gate.** If you see a failure count other than two on a plain `mvn verify`, stop and check
with your facilitator before continuing.

**Close the stage.** `/hand-off` — cite the new test files and the `mvn test`/`mvn verify` output
confirming the red state.

**Invariant.** Two new test slices exist, asserting intended/secure behavior; both red;
`BaselineTest` and everything else stays green; no production code modified this stage.

---

## Stage 4 — Remediate and build (35 min · the largest block)

**Objective.** F1 and F2 fixed under fresh-context review, F8 resolved, and
`processOnlineRefund()` built to spec.

**Action.**

1. Fix F1 with the smallest diff. Validate. Send it through a fresh-context `pr-reviewer` pass —
   one that never saw the fix get written.
2. Fix F2 the same way.
3. `mvn verify` will still fail on ArchUnit until F8 is addressed — move the
   privilege-evaluation logic out of `RefundController` into `RefundService`. You don't have to
   hunt for this by eye; the build tells you.
4. Build `processOnlineRefund()`: honour `TOGGLE_ENABLE_ONLINE_REFUND`, null the authorization
   code from retrieval unless the return-authorization-data toggle is ON (online refunds only —
   the offline response legitimately still returns it), do **not** write settlement records.
   Online-vs-offline is selected by the request body's `wsApiSupport.refundAuthorization`, not a
   separate URL.
5. **Watch the traps:** a PAN-masking-library request should fail the unknown-dependency check;
   an offer to write the settlement leg should be declined; a naive build that skips the
   `EXCESSIVE_REFUNDS` check reproduces F6 live — note it, it's still backlog, not a new fix
   target.
6. Update `RISK_REGISTER.md` (status changes for F1, F2, F8) and `FIXES.md` — fill in the
   existing table (don't replace it with prose; `grade_repo.py` reads actual table rows), one row
   per fix, with the `pr-reviewer` verdict.

**Artifacts.** F1/F2/F8 fixes · `processOnlineRefund()` · updated `RISK_REGISTER.md` and
`FIXES.md`.

**Human gate.** Each fix reviewed fresh-context before you move to the next one — the failure
mode this gate exists to catch is *accepting a fix unread because you already believe it works*.

**Failure / recovery.** If your group is behind by the 20-minute mark of this stage, ask your
facilitator for the `reference/` fallback rather than rushing the fresh-context review step.

**Close the stage.** `/hand-off` — cite the fixes, `processOnlineRefund()`, `RISK_REGISTER.md`,
and `FIXES.md` as this stage's artifacts.

**Invariant.** `mvn verify` passes ArchUnit; F1/F2/F8 all resolved; `processOnlineRefund()` built
to spec; `FIXES.md` has a real table row per fix with a recorded reviewer verdict.

---

## Stage 5 — Look ahead (8 min)

**Objective.** Name what's next without doing it. No code changes this stage.

**Surface.** `planner`, in guide mode.

**Prompt.**

> "Write `docs/secure-features-guide.md` describing proactive controls to adopt next, grounded in
> this codebase: correlation IDs end to end, wiring up or removing the dead-weight
> `ENABLE_REFUND_REQUESTS`/`SUPPORT_EXTENDED_REFUNDS` privileges, config externalisation for the
> settlement-notify URL, deny-by-default validation, and structured error handling via
> `@ControllerAdvice`. No code changes."

**Artifact.** `docs/secure-features-guide.md`.

**Human gate.** Review it: every recommendation should be grounded in something specific to this
codebase (a real backlog finding — F7, F9, F10, F11, F16 — or a real gap in the current design),
not generic security advice that could apply to any service.

**Close the stage.** `/hand-off` — cite `docs/secure-features-guide.md` as this stage's artifact.

**Invariant.** `docs/secure-features-guide.md` exists; every recommendation ties back to something
concrete in this codebase; no code changed this stage.

---

## Stage 6 — Close (7 min)

**Objective.** Evidence, audit trail, grade. Nothing is done until someone who wasn't in the room
can verify it from the artifacts alone.

**Action.**

1. Run `mvn verify` — confirm it's fully green: ArchUnit, the compile/test suite, JaCoCo report
   generated.
2. Update `SECURITY.md`: F1, F2, F8 as Security Controls (cite the fix and its `pr-reviewer`
   verdict); F3, F4, F6, F7, F9–F16 as Known Risks; **F5 explicitly marked escalated, not
   defaulted** — its own row, not folded into the others.
3. Confirm `docs/workflow-tracker.md` has a `/hand-off` entry for every stage (0 through 6), each
   one citing the specific artifact filename that stage produced — not a repeated template.
4. Grade yourself:
   ```bash
   python3 .claude/scripts/grade_repo.py
   ```
   **Do not use the plugin's own `/grade`** — as of workbench 0.2.0, its `lab-grader` only
   supports four generic check types and does not understand this rubric's content-based checks;
   running `/grade` against `.claude/rubrics/finish-the-refund.rubric.yaml` silently scores those
   criteria 0 regardless of what you did. `grade_repo.py` is the real, deterministic grader for
   this rubric — read the per-criterion breakdown, not just the overall score. A passing grade
   with a failed F5 content check is not actually a pass of the lab's central lesson.
5. Recap as a group: direct-prompt comprehension vs. the fresh-context review loop; two traced
   fixes plus one mechanically-caught layering fix; a documented backlog including one gap
   escalated rather than silently defaulted.

**Artifacts.** `SECURITY.md` · complete `docs/workflow-tracker.md` · the `grade_repo.py` grade
card.

**Human gate.** `mvn verify` fully green; grade breakdown reviewed, not just the headline
percentage.

**Close the stage.** `/hand-off` — cite `SECURITY.md` and the grade output as this stage's
artifacts.

**Invariant.** `mvn verify` fully green; `SECURITY.md` complete with F5 explicitly escalated;
`docs/workflow-tracker.md` has all 7 stage entries, each citing a real artifact.

---

## Where each artifact goes

Paths are what the grader and the gates look at.

| Stage | Artifact |
|---|---|
| 0 | plugin installed; a journey event in `.claude/journey/` |
| 1 | `RISK_REGISTER.md` |
| 2 | `docs/plans/plan.md` |
| 3 | new test files under `src/test/java/…` |
| 4 | F1/F2/F8 fixes · `processOnlineRefund()` · `RISK_REGISTER.md` · `FIXES.md` |
| 5 | `docs/secure-features-guide.md` |
| 6 | `SECURITY.md` · `docs/workflow-tracker.md` · the grade card |
| every stage | a `hand-off` entry in `docs/workflow-tracker.md` |

## Grading

Two layers, both reproducible.

**Layer A — journey completeness** (the plugin's own `lab-grader`, if you run it): did you move
through the stages, and did the audit trail stay free of sensitive data? It proves progress, not
correctness — and this rubric's richer content checks don't run through it (see Stage 6 above).

**Layer B — repo state and behaviour:**

```bash
python3 .claude/scripts/grade_repo.py
```

Deterministic checks against `.claude/rubrics/finish-the-refund.rubric.yaml` — the same repo
state always yields the same score. Checks register completeness, F1/F2/F8 resolution with a
recorded reviewer verdict, F5 escalation (not defaulting), and the secure-features-guide content —
not file existence, actual content.

---

## What you leave with

- A registered, prioritized sixteen-finding risk register, F5 explicitly escalated or explicitly
  missed — never silently skipped.
- F1 and F2 fixed under fresh-context review; F8 resolved; `processOnlineRefund()` built to spec.
- The evidence: `RISK_REGISTER.md`, `docs/plans/plan.md`, the new tests, `FIXES.md`,
  `docs/secure-features-guide.md`, `SECURITY.md`, seven hand-offs, the journey, and a grade card.

## The five things this lab is actually about

1. **Hallucination, felt firsthand** — not defined on a slide, personally caught once.
2. **Correctly solving the wrong problem, and incorrectly solving the right one** — both are real,
   both look like progress, only one of them is what the spec actually asked for.
3. **Sycophancy is the one that matters most.** The reviewer that already believes the work is
   done will pass it. The one that doesn't know you won't — that's the fresh-context `pr-reviewer`
   gate, not a formality.
4. **Invented dependencies** — an agent reaching for a library or a call that doesn't exist on
   this path, offered with total confidence.
5. **A green build tells you the code ran — not that it's safe.** F8 is caught by the build; the
   other fifteen findings are not, and a passing test suite says nothing about any of them.

## See also

- [`AGENTS.md`](./AGENTS.md) — canonical rule, subagent, command, and hook reference
- [`README.md`](./README.md) — architecture note, prerequisites, generated artifacts
- [`docs/FACILITATOR_KEY.md`](./docs/FACILITATOR_KEY.md) — facilitator answer key (not for
  participants)
- [`docs/SOURCE_TRACEABILITY.md`](./docs/SOURCE_TRACEABILITY.md) — which design decisions come
  from the real PGS spec pack and which are labelled lab assumptions
- [`exercises/`](./exercises/) — per-stage instructions, exact prompts, and a
  predict-before-you-look hypothesis exercise
- [`specs/refunds-s2i-phase1.spec.md`](./specs/refunds-s2i-phase1.spec.md) — the spec this lab is
  built against
