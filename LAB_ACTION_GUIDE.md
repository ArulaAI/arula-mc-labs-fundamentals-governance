# Lab 1: Finish the Refund

**Thread:** `G1190-3291` Support Refunds for S2I transactions, Phase 1 (Processing domain) ·
**Level:** 100 → 200 · **Duration:** 120 minutes · **Topology:** one repo, the real PGS contract

---

## The scenario

A squad member got the offline refund path working (tests green, build clean), then got pulled
onto a Sev-2 before finishing the harder case. The online path is still an
`UnsupportedOperationException`. You inherit the file. It merges Thursday. Nothing in the diff
looks wrong. That's exactly the problem: this one file carries sixteen real governance findings,
traced to the real PGS spec pack, that a passing build will never show you.

**Your role:** the engineer finishing the inherited file, with an AI assistant as your pair.

**What you are building:** two findings fixed by hand under fresh-context review, one finding
caught mechanically by the build (F8's layering violation; you don't hunt for it, `mvn verify`
tells you), and `processOnlineRefund()` built from scratch to spec: the feature toggle honoured,
the authorization code correctly nulled on retrieval, no settlement record written.

**This is also the first lab in the series**, so Stage 0 below walks you through installing the
`workbench` plugin itself. Every later lab assumes that part is already done.

---

## Setup

### Prerequisites

- JDK 17 (Zulu recommended), Maven 3.9+
- Claude Code: teach on whatever version you actually have; no upgrade required. Live-tested
  this pass on both 2.1.108 and 2.1.234: the plugin installs, lists as enabled, and validates
  cleanly on both.
- The `workbench` plugin: installed in Stage 0, not before. If you want it ready ahead of time
  anyway, the two commands are in Stage 0 below.

### Preflight (before the session starts)

1. `java -version` → 17.x (or 21.x compiling to target 17) · `mvn -version` → 3.9+
2. Pre-warm the Maven cache once per machine: `mvn -q -o dependency:go-offline`. This service
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
   This **should fail**, on exactly one thing, an ArchUnit layering-violation message. That's
   intended, not a broken lab: F8 is caught by the build itself, and you fix it in Stage 4. If
   `mvn verify` fails for any other reason, or passes cleanly, flag your facilitator before
   continuing.

---

## What is already true when you start

- `mvn test` is **green**.
- The offline refund path works.
- The online path throws `UnsupportedOperationException`, genuinely unbuilt.
- `mvn verify` is **red**, on exactly one ArchUnit message (F8).
- Sixteen findings are seeded in this one file; none are fixed yet.

---

## Stage 0: Ground the room, install the harness, meet the five failure modes (18 min)

**Objective.** A confirmed-working plugin install and shared vocabulary before anyone touches a
keyboard. An ungrounded room diverges within ten minutes, and since this is the first lab, "the
harness" includes actually installing it, not just confirming it.

**Action.**

1. Install the plugin, live, together. It comes from a small **private** marketplace that ships
   in the plugin repo itself, not a public registry:
   ```bash
   claude plugin marketplace add https://github.com/ArulaAI/arula-mc-labs-plugin
   claude plugin install workbench@mastercard-workbench
   ```
   No clone needed just for this: `marketplace add` fetches the repo directly. Confirmed working
   identically on 2.1.108 and 2.1.234 this pass. **On 2.1.108, omit `-y`**: that flag doesn't
   exist there yet; the plain command completes fine without it.
2. Facilitator walks the room through: agents vs. skills vs. commands vs. rules (what each piece
   of the `workbench` plugin actually is); model tiers and when to use which; why context
   degrades over a long session; what determinism means when the underlying model is
   probabilistic; why an agent reviewing its own work tends to pass it.
3. The five failure modes, named explicitly. You'll meet all five, firsthand, this lab:
   - **Hallucination**: inventing behavior, fields, or dependencies the spec never mentions
   - **Correctly solving the wrong problem**: building something real and well-engineered that
     was never in scope
   - **Incorrectly solving the right problem**: the right feature, built with a gap the spec's
     edge cases exposed
   - **Sycophancy**: an agent (or a person) reviewing its own work and approving it
   - **Invented dependencies**: adding a call to a service, library, or check that doesn't
     exist on this path
4. **What "spec" means in this lab.** When this lab says "the spec," it means the engineering-ready
   tech spec at `specs/refunds-s2i-phase1.spec.md` — the document you compare code against in
   Stage 1. This lab does not produce or validate the upstream PRD or design spec that a
   product/PMT team would own. PMT-side spec authorship and sign-off is a known, explicitly
   out-of-scope gap for this series, not a silent omission.

**Commands.** `/lab` → confirm it reports lab id `finish-the-refund`, targets `F1, F2`, and a
120-minute budget. Then **confirm a journey event actually landed** in `.claude/journey/`: open
the directory, don't just trust the command's exit code. On Windows this is where a silent
bash/PATH issue would otherwise surface at Stage 6 instead of now.

**Human gate.** Room can name all five failure modes without looking them up; `/lab` reports the
correct id/targets/budget; a journey event file exists.

**Failure / recovery.** `claude plugin marketplace add` fails or times out → check network access
to GitHub before anything else; retry once. `/lab` not recognized after a successful install →
confirm Claude Code is open at the repo root, not a parent or child directory. No journey event
despite `/lab` working → the plugin installed but its hooks aren't wired for this session; flag
your facilitator, don't proceed into Stage 1 ungraded.

**Close the stage.** `/hand-off`: cite the confirmed harness state (plugin installed, journey
event present, plugin commands listed) as this stage's artifact.

**Invariant.** Plugin installed and validated; harness live; room can name the five failure modes.

---

## Stage 1: Comprehend and register (25 min)

**Objective.** A registered, prioritized `RISK_REGISTER.md` with all sixteen findings, not just
the ones you plan to fix.

**Action.**

1. **First, with your own eyes, no AI.**
   - Start the app: `mvn spring-boot:run`. It runs in the foreground and streams logs. Open a
     **second terminal** in the same repo for the requests below; don't close the first one, you
     need to watch its log output in step 2.
   - Submit the same refund request twice, with the same `idempotencyKey`, from the second
     terminal:
     ```bash
     curl -s -X POST http://localhost:8080/card-payments/cpg-1001/refunds \
       -H "Content-Type: application/json" \
       -d '{
         "merchantWsApiId": "merchant-0001",
         "paymentCurrency": "USD",
         "amounts": { "transactionAmount": 2500 },
         "merchantOrder": { "transactionReference": "ref-0001" },
         "wsApiSupport": {
           "transactionWsApiId": "txn-0001",
           "orderWsApiId": "order-0001",
           "wsApiVersion": "1.0",
           "targetTransactionWsApiId": null,
           "refundAuthorization": null
         },
         "idempotencyKey": "idem-demo-1",
         "merchantPrivileges": ["REFUNDS"]
       }' | jq
     ```
     Run that exact command a second time, unchanged. Expected: two `200 OK` responses, each with
     a **different** `authorizationCode`; two records, not one 409 on the retry.
   - Switch to the first terminal (still running `mvn spring-boot:run`) and look at the log:
     you'll see two `INFO ... Processed offline refund: ...` lines, each showing the
     `authorizationCode` (`AUTH-...`) in cleartext.
   - Back in the second terminal, try void, which shouldn't exist at all per
     `specs/OUT_OF_SCOPE.md`:
     ```bash
     curl -s -X POST http://localhost:8080/card-payments/cpg-1001/void \
       -H "Content-Type: application/json" \
       -d '{
         "merchantWsApiId": "merchant-0001",
         "paymentCurrency": "USD",
         "amounts": { "transactionAmount": 2500 },
         "merchantOrder": { "transactionReference": "ref-0001" },
         "wsApiSupport": {
           "transactionWsApiId": "txn-0001",
           "orderWsApiId": "order-0001",
           "wsApiVersion": "1.0",
           "targetTransactionWsApiId": null,
           "refundAuthorization": null
         },
         "idempotencyKey": "idem-void-1",
         "merchantPrivileges": ["REFUNDS"]
       }' | jq
     ```
     Expected: a `200 OK` with a full refund record back, `"status": "VOIDED"`. Note: it looks up
     the record by `transactionId`, not `idempotencyKey`, so the `idempotencyKey` you send here
     is ignored, and you'll see the *original* refund's `idempotencyKey` (`idem-demo-1`) echoed
     back in the response, not `idem-void-1`. That's expected too; the point of this check is that
     the endpoint answers at all, not its internal lookup key.
   - `Ctrl+C` the first terminal to stop the app once all three checks are done.
2. Read `specs/refunds-s2i-phase1.spec.md` and `specs/OUT_OF_SCOPE.md` in full.
3. **Then** direct-prompt Claude Code. This prompt does two passes in one: a comprehension
   table, then an explicit check against the spec's own business rules. That second half is what
   surfaces spec-level findings (like the missing `EXCESSIVE_REFUNDS` gate) that reading the code
   alone won't show you:
   ```
   Review these files together: RefundController.java, RefundService.java, RefundPrivilege.java, PreRiskAssessmentClient.java, RefundRecordDao.java, RefundHealthIndicator.java. For each file return a table: file | responsibility | key dependencies | hidden side effects. Then separately, compare the code against every business rule in specs/refunds-s2i-phase1.spec.md, rule by rule, and flag any rule the code does not appear to satisfy. Do not suggest fixes. Do not create the risk register yet.
   ```
4. **Read what comes back once, don't audit it against a checklist you don't have.** A realistic
   first pass surfaces roughly 11-12 of the sixteen findings this way, on top of the two or three
   you already found unaided in step 1. That's the expected yield, not a shortfall to go hunting
   for. Reject anything that sounds plausible but is actually out of scope, with a stated reason
   (a couple of decoys are seeded on purpose). That's real triage, a five-second gut check per
   row, not a re-read of the code.
5. **Write the register.** Hand the finished review straight to Claude Code:
   ```
   Write RISK_REGISTER.md as a table: ID | Name | Severity | Failure mode | Affected files | Impact | Status, using everything from the review above. Mark REFUND_EXPIRY 'Escalated, value undefined in spec, not defaulted,' never invent a number for it. All Status = Open.
   ```
6. **The one thing worth a manual glance, not a full audit.** Open the finished file and confirm
   the `REFUND_EXPIRY` row actually says escalated, not a made-up window value. That's the one
   spot an AI under pressure to look complete might quietly invent an answer instead of admitting
   the spec left it blank. If your group's table is short of the sixteen after this (some groups
   miss `EXCESSIVE_REFUNDS`, F6, since it's a spec-only rule with no visible code symptom yet, or
   F7's missing correlation ID, an absence rather than a wrong line), that's a normal gap to close
   at the Stage 1 debrief, not something to have caught yourselves mid-stage.

**Artifact.** `RISK_REGISTER.md`, all sixteen rows.

**Human gate.** At least two findings found unaided, before any AI involvement; at least two
decoys explicitly rejected with a stated reason; F5's status explicit either way.

**Failure / recovery.** `docs/FACILITATOR_KEY.md` is the answer key. Nothing blocks you from
opening it early; that's on your own discipline, not a hook. Opening it before you've registered
your own findings just means you're grading your own homework.

**Close the stage.** `/hand-off`: cite `RISK_REGISTER.md` as this stage's artifact.

**Invariant.** All sixteen findings registered, each citing a real affected file; F5's status
stated explicitly, not silently skipped.

---

## Stage 2: Plan (12 min)

**Objective.** An ordered remediation plan, Critical first, scoped to exactly F1, F2, and building
`processOnlineRefund()`, nothing else.

**Surface.** The `planner` subagent. The prompt names it explicitly so Claude delegates to a
fresh-context agent instead of planning in-session (which would defeat the point of producing a
plan independently of the register you just wrote).

**Prompt.**

```
Using the planner subagent: break down RISK_REGISTER.md against specs/refunds-s2i-phase1.spec.md into an ordered remediation plan scoped to F1 and F2 plus building processOnlineRefund(). Per step: target file(s), one-line fix or build task, expected post-fix state, success criterion. Critical severity first. Save to docs/plans/plan.md.
```

**Artifact.** `docs/plans/plan.md`.

**Human gate.** Review the plan yourself against `payments-guardrails` and the spec's own
acceptance criteria before moving on. Close any gap you find: patch `docs/plans/plan.md` by hand
for something small, or re-run the planner prompt for anything that changes scope or ordering —
don't just wave the gap through. Don't accept a plan that silently expands scope (a step touching
F3–F16) or silently narrows it (no step for the online-path build).

**Close the stage.** `/hand-off`: cite `docs/plans/plan.md` as this stage's artifact.

**Invariant.** Plan exists, Critical-severity steps first; every step maps to F1, F2, or the
online-path build, each naming its target file(s) and a concrete success criterion.

---

## Stage 3: Prove it's broken (15 min)

**Objective.** Two new red test slices, proving F1 and F2 are real, before touching any
production code.

**Prompt.**

```
Write JUnit 5 tests asserting the INTENDED behavior:

- F1, LOGS ONLY: no authorization code appears in RefundService's log output (neither the INFO success line nor the ERROR line in the catch block) for an offline refund. Use Spring Boot's OutputCaptureExtension (already available via spring-boot-starter-test) with a CapturedOutput parameter; do not add a new dependency for this. Do NOT assert the offline RESPONSE body is scrubbed: the spec scopes authorization-code nulling to ONLINE refund retrieval only, so the offline response legitimately still carries it. Assert it is still present, to pin the scope of the fix.
- F2: a retried refund with the same idempotencyKey returns a decline/409 and creates no second record.

Build request objects with com.mc.pgs.refunds.support.RefundRequestFixtures; do not hand-assemble the nested amounts/merchantOrder/wsApiSupport structure. Deterministic tests, follow existing conventions. Do not modify production code.
```

**Why F1's slice is logs-only.** A test asserting the offline response is scrubbed would still be
red after a completely correct fix. That's not proving it's broken, it's proving the test wrong.
If Claude Code volunteers that assertion anyway, notice it: generalising a real rule past its
stated scope is exactly the failure mode this stage exists to make visible.

**Artifacts.** Two new test slices.

**Observable.** `mvn test` shows exactly the two new reds, everything else green. `mvn verify`
reports the same two, not three: Maven stops at the first failing phase, so a plain invocation
never reaches the later `verify`/failsafe phase where `ArchitectureIT` (F8) lives once earlier
tests are red. F8's red is real and unchanged, just not re-reported in this run. To see all three
together: `mvn verify -Dmaven.test.failure.ignore=true` (the final line will say `BUILD SUCCESS`
even though three things failed: that's what "ignore" means to Maven; read the `[ERROR]` blocks,
not the last line).

**Human gate.** If you see a failure count other than two on a plain `mvn verify`, stop and check
with your facilitator before continuing.

**Close the stage.** `/hand-off`: cite the new test files and the `mvn test`/`mvn verify` output
confirming the red state.

**Invariant.** Two new test slices exist, asserting intended/secure behavior; both red;
`BaselineTest` and everything else stays green; no production code modified this stage.

---

## Stage 4: Remediate and build (35 min · the largest block)

**Objective.** F1 and F2 fixed under fresh-context review, F8 resolved, and
`processOnlineRefund()` built to spec.

**Action.**

1. **Fix F1.** run them in order:

   **(a) Fix prompt**, normal, direct-prompt Claude Code, no subagent yet:
   ```
   Fix F1: the INFO log line in RefundService.processOfflineRefund() logs the full RefundRecord, which includes the authorization code. Change it to log only non-sensitive fields (transactionId, amountMinor, status), excluding authorizationCode entirely.
   Smallest possible diff, don't touch anything else in this method.
   ```

   **(b) Validate it yourself:**
   ```bash
   mvn test
   ```
   Confirm `RefundServiceLoggingTest.offlineRefund_successLine_doesNotLogAuthorizationCode`
   (red since Stage 3) is now green, and nothing else broke.

   **(c) Review prompt**, only after (a) and (b), subagent named explicitly:
   ```
   Using the pr-reviewer subagent: review the diff of my F1 fix against coding-standards.md with clean context — you did not write this code. Return PASS or FAIL with specific findings.
   ```
   **Do not just ask "did I get this right" in the same conversation.** That's self-review,
   not the fresh-context review this stage is built to teach.

   **(d) Confirm the subagent actually ran.** Check Claude Code's tool-call output: you should
   see an `Agent (pr-reviewer)` tool invocation, not just inline text. If the review happened
   in-session without spawning a subagent, the whole point of fresh-context review is lost — ask
   it to redo using the pr-reviewer subagent.

   **(e) If the pr-reviewer returned FAIL:** address each specific finding with a new prompt (not
   a same-thread "did I get this right"), re-run `mvn test`, then re-invoke the pr-reviewer
   subagent fresh — repeat until PASS.

2. **Fix F2, same steps, same order:**

   **(a) Fix prompt:**
   ```
   Fix F2: add the missing idempotency check to RefundService.processOfflineRefund(). refundRecordDao.findByIdempotencyKey() already exists and is ready to use, it just has no caller yet. Look up the idempotency key before inserting; if a record already exists, return a 409 decline instead of inserting a second record. Smallest possible diff.
   ```

   **(b) Validate:**
   ```bash
   mvn test
   ```
   Confirm `RefundServiceIdempotencyTest` is now green.

   **(c) Review prompt:**
   ```
   Using the pr-reviewer subagent: review the diff of my F2 fix against coding-standards.md with clean context — you did not write this code. Return PASS or FAIL with specific findings.
   ```

   **(d) Confirm the subagent actually ran.** Same check as F1: look for the `Agent (pr-reviewer)`
   tool invocation in Claude Code's output. If it reviewed in-session, ask it to redo with the
   subagent.

   **(e) If the pr-reviewer returned FAIL:** address each specific finding with a new prompt (not
   a same-thread "did I get this right"), re-run `mvn test`, then re-invoke the pr-reviewer
   subagent fresh — repeat until PASS.
3. `mvn verify` will still fail on ArchUnit until F8 is addressed: move the
   privilege-evaluation logic out of `RefundController` into `RefundService`. You don't have to
   hunt for this by eye; the build tells you.
4. **Build `processOnlineRefund()`.** Run this prompt:
   ```
   Build processOnlineRefund() in RefundService, replacing the current UnsupportedOperationException. Follow the spec: honour the TOGGLE_ENABLE_ONLINE_REFUND feature toggle. For online refunds, null the authorization code from the response unless the return-authorization-data-to-merchants toggle is explicitly ON, the offline path is unaffected and should keep returning the code as it does today. Do not write any settlement record, that leg is downstream and out of scope. Online vs offline is selected by the request body's wsApiSupport.refundAuthorization field, not a separate URL or endpoint. Follow this file's existing conventions and use RefundRequestFixtures for any new tests.
   ```
   Validate: `mvn verify`, which should pass everything now, including ArchUnit from step 3.
5. Update `RISK_REGISTER.md` (status changes for F1, F2, F8) and `FIXES.md`: fill in the
   existing table (don't replace it with prose; `grade_repo.py` reads actual table rows), one row
   per fix, with the `pr-reviewer` verdict.

**Artifacts.** F1/F2/F8 fixes · `processOnlineRefund()` · updated `RISK_REGISTER.md` and
`FIXES.md`.

**Human gate.** Each fix reviewed fresh-context before you move to the next one. The failure
mode this gate exists to catch is *accepting a fix unread because you already believe it works*.

**Failure / recovery.** If your group is behind by the 20-minute mark of this stage, ask your
facilitator for the `reference/` fallback rather than rushing the fresh-context review step.

**Close the stage.** `/hand-off`: cite the fixes, `processOnlineRefund()`, `RISK_REGISTER.md`,
and `FIXES.md` as this stage's artifacts.

**Invariant.** `mvn verify` passes ArchUnit; F1/F2/F8 all resolved; `processOnlineRefund()` built
to spec; `FIXES.md` has a real table row per fix with a recorded reviewer verdict.

---

## Stage 5: Look ahead (8 min)

**Objective.** Name what's next without doing it. No code changes this stage.

**Surface.** The `planner` subagent, in guide mode. Same rule as Stage 2: name the subagent
explicitly so Claude delegates instead of doing it in-session.

**Prompt.**

```
Using the planner subagent in guide mode: analyze the open findings in RISK_REGISTER.md and produce docs/secure-features-guide.md — a forward-looking guide describing proactive controls to adopt next, grounded in this codebase: correlation IDs end to end, wiring up or removing the dead-weight ENABLE_REFUND_REQUESTS/SUPPORT_EXTENDED_REFUNDS privileges, config externalisation for the settlement-notify URL, deny-by-default validation, and structured error handling via @ControllerAdvice. No code changes.
```

**Artifact.** `docs/secure-features-guide.md`.

**Human gate.** Review it: every recommendation should be grounded in something specific to this
codebase, either a real backlog finding (F7, F9, F10, F11, F16) or a real gap in the current
design, not generic security advice that could apply to any service.

**Close the stage.** `/hand-off`: cite `docs/secure-features-guide.md` as this stage's artifact.

**Invariant.** `docs/secure-features-guide.md` exists; every recommendation ties back to something
concrete in this codebase; no code changed this stage.

---

## Stage 6: Close (7 min)

**Objective.** Evidence, audit trail, grade. Nothing is done until someone who wasn't in the room
can verify it from the artifacts alone.

**Action.**

1. Run `mvn verify` and confirm it's fully green: ArchUnit, the compile/test suite, JaCoCo report
   generated.
2. Update `SECURITY.md`: F1, F2, F8 as Security Controls (cite the fix and its `pr-reviewer`
   verdict); F3, F4, F6, F7, F9–F16 as Known Risks; **F5 explicitly marked escalated, not
   defaulted**, in its own row, not folded into the others.
3. Confirm `docs/workflow-tracker.md` has a `/hand-off` entry for every stage (0 through 6), each
   one citing the specific artifact filename that stage produced, not a repeated template.
4. Grade yourself:
   ```bash
   python3 .claude/scripts/grade_repo.py
   ```
   **Do not use the plugin's own `/grade`.** As of workbench 0.2.0, its `lab-grader` only
   supports four generic check types and does not understand this rubric's content-based checks;
   running `/grade` against `.claude/rubrics/finish-the-refund.rubric.yaml` silently scores those
   criteria 0 regardless of what you did. `grade_repo.py` is the real, deterministic grader for
   this rubric. Read the per-criterion breakdown, not just the overall score. A passing grade
   with a failed F5 content check is not actually a pass of the lab's central lesson.
5. Recap as a group: direct-prompt comprehension vs. the fresh-context review loop; two traced
   fixes plus one mechanically-caught layering fix; a documented backlog including one gap
   escalated rather than silently defaulted.

**Artifacts.** `SECURITY.md` · complete `docs/workflow-tracker.md` · the `grade_repo.py` grade
card.

**Human gate.** `mvn verify` fully green; grade breakdown reviewed, not just the headline
percentage.

**Close the stage.** `/hand-off`: cite `SECURITY.md` and the grade output as this stage's
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
| 7 (optional) | your own attack/defense notes (ungraded) |

## Grading

Two layers, both reproducible.

**Layer A: journey completeness** (the plugin's own `lab-grader`, if you run it): did you move
through the stages, and did the audit trail stay free of sensitive data? It proves progress, not
correctness, and this rubric's richer content checks don't run through it (see Stage 6 above).

**Layer B: repo state and behaviour**

```bash
python3 .claude/scripts/grade_repo.py
```

Deterministic checks against `.claude/rubrics/finish-the-refund.rubric.yaml`: the same repo
state always yields the same score. Checks register completeness, F1/F2/F8 resolution with a
recorded reviewer verdict, F5 escalation (not defaulting), and the secure-features-guide content.
Not file existence, actual content.

---

## Stage 7: Break the Gates (Optional, 20 min)

**Objective.** Stress-test the governance stack you just learned to trust. Try to get Claude Code
to violate a rule -- log a secret, write to a guarded path, sneak in an unknown dependency --
without the hooks or gates catching it.

You spent the lab working *within* governance. Now try to break it.

**Action.** Read [`docs/CHALLENGE_BREAK_THE_GATES.md`](docs/CHALLENGE_BREAK_THE_GATES.md) for the
full brief: rules of engagement, five attack-surface categories to explore, and what to document.

**No rubric, no grading, no hand-off.** This is optional. If you find a real bypass, flag your
facilitator -- that's a genuine contribution to the repo's governance, not a game artifact.

**Share-out.** When time is up, the room compares notes. Thirty people trying thirty different
angles will surface more about this governance stack than any single review could.

---

## What you leave with

- A registered, prioritized sixteen-finding risk register, F5 explicitly escalated or explicitly
  missed, never silently skipped.
- F1 and F2 fixed under fresh-context review; F8 resolved; `processOnlineRefund()` built to spec.
- The evidence: `RISK_REGISTER.md`, `docs/plans/plan.md`, the new tests, `FIXES.md`,
  `docs/secure-features-guide.md`, `SECURITY.md`, seven hand-offs, the journey, and a grade card.

## The five things this lab is actually about

1. **Hallucination, felt firsthand**: not defined on a slide, personally caught once.
2. **Correctly solving the wrong problem, and incorrectly solving the right one**: both are real,
   both look like progress, only one of them is what the spec actually asked for.
3. **Sycophancy is the one that matters most.** The reviewer that already believes the work is
   done will pass it. The one that doesn't know you won't. That's the fresh-context `pr-reviewer`
   gate, not a formality.
4. **Invented dependencies**: an agent reaching for a library or a call that doesn't exist on
   this path, offered with total confidence.
5. **A green build tells you the code ran, not that it's safe.** F8 is caught by the build; the
   other fifteen findings are not, and a passing test suite says nothing about any of them.

## See also

- [`AGENTS.md`](./AGENTS.md): canonical rule, subagent, command, and hook reference
- [`README.md`](./README.md): architecture note, prerequisites, generated artifacts
- [`docs/FACILITATOR_KEY.md`](./docs/FACILITATOR_KEY.md): facilitator answer key (not for
  participants)
- [`docs/SOURCE_TRACEABILITY.md`](./docs/SOURCE_TRACEABILITY.md): which design decisions come
  from the real PGS spec pack and which are labelled lab assumptions
- [`specs/refunds-s2i-phase1.spec.md`](./specs/refunds-s2i-phase1.spec.md): the spec this lab is
  built against
