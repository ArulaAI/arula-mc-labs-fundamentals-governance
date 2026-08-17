# Facilitator Key — Finish the Refund

**Not for participants.** This is the answer key: the full finding list, the smallest-diff
remediation outline for F1/F2/F8, the exact secure behaviors Stage 3's tests must assert, where
every failure-mode trap bites, the expected green/red state at each checkpoint, the realistic
Stage 1 yield, and the documented Stage-4 fallback prompt.

## Full finding list

| ID | Name | Severity | Failure mode | Affected files | Status this lab |
|---|---|---|---|---|---|
| F1 | Authorization code and full refund record logged at INFO; raw request logged on failure | Critical | Sensitive data leak | `RefundService.java` | **Remediated** (target) |
| F2 | No idempotency — a retried refund creates a second record; 409 never returned | Critical | Incorrectly solving the right problem | `RefundService.java` | **Remediated** (target) |
| F3 | `voidRefund()` answers on `POST /card-payments/{card_payment_gateway_id}/void` — Void is explicitly out of scope | High | Correctly solving the wrong problem | `RefundController.java` | Registered, left `Open` |
| F4 | `PreRiskAssessmentClient` called — spec has no pre-risk-assessment step on this path | Medium | Hallucinated dependency | `PreRiskAssessmentClient.java` | Registered, left `Open` |
| F5 | `REFUND_EXPIRY` privilege exists; the window's value is genuinely undefined in the spec pack | High | Unauthorised default if silently invented | `RefundPrivilege.java` | **Registered + escalated** — not the same status as backlog |
| F6 | No gate checking `EXCESSIVE_REFUNDS` on the excessive-refund path | High | Missing privilege gate | `RefundService.java` | Registered — **live trap during Stage 4**, see below |
| F7 | No correlation ID propagated end-to-end | Low (hygiene) | — | `RefundController.java` | Backlog |
| F8 | Controller depends on `RefundRecordDao` directly; privilege check lives in the controller | High | Layering violation | `RefundController.java` | **Remediated, mechanically** — `ArchitectureIT` fails `mvn verify` until fixed |
| F9 | Hardcoded downstream settlement-notify URL | Low (hygiene) | — | `RefundService.java` | Backlog |
| F10 | No `@ControllerAdvice` — inconsistent error shape vs. Spring's default | Medium (hygiene) | — | `RefundController.java` | Backlog |
| F11 | `RefundHealthIndicator` reports UP on `/actuator/health` without checking anything — a health endpoint that cannot fail | Low (hygiene) | — | `RefundHealthIndicator.java` | Backlog |
| F12 | No `REFUNDS` privilege gate on the base refund path — a merchant with no privileges still gets a refund processed | High | Missing privilege gate | `RefundService.java` | Backlog |
| F13 | No currency-match validation against the original transaction | Medium | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F14 | No voided-target rejection — a VOIDED transaction can still be refunded | High | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F15 | No positive-input validation at all — a negative amount or malformed currency is accepted and processed | High | Incorrectly solving the right problem | `RefundService.java` | Backlog |
| F16 | `ENABLE_REFUND_REQUESTS` and `SUPPORT_EXTENDED_REFUNDS` declared in `RefundPrivilege` but never read anywhere — dead-weight, not backed by any check | Medium (hygiene) | — | `RefundPrivilege.java` | Backlog |

**Only F1 and F2 are remediation targets this pass** (`.claude/lab.json` `targets`), plus
building `processOnlineRefund()`. **F8 gets resolved too, but mechanically** — `mvn verify`
genuinely will not go green until it's fixed, so participants don't have to find it by eye; the
build finds it for them. F5 is registered and escalated, which is a *different* status from the
plain backlog items (F3, F4, F6, F7 and F9–F16) — a participant who lumps F5 in with ordinary
backlog, or worse, invents a default window value for it, has failed the lab's central lesson
even if F1/F2/F8 are all correctly fixed.

**F15 and F16, added on a later hardening pass, not in the original build.** Both surfaced from
a direct line-by-line read of the raw PGS spec pack and Mastercard's own "Internal standards"
document, not from a prior review round. F15 (missing positive-input validation) matters more
than its "hygiene"-adjacent framing suggests — Mastercard's Eng Std 5.1–5.3 names positive input
validation a non-negotiable, the same tier as F1/F2, not an optional nicety; it's kept as
backlog rather than a third remediation target only to avoid destabilizing the Stage 3 "exactly
two reds" checkpoint invariant this close to a live cohort run, not because it's less real. F16
is lower-stakes: two privileges that exist in name only. If a participant asks "what does
`ENABLE_REFUND_REQUESTS` actually gate," the honest answer is nothing — point them at F16 rather
than let them assume it's silently handled.

**A spec ambiguity worth surfacing to the group if it comes up, not resolved silently either
way:** the spec pack's own "Out of scope (Phase 1)" list states "Excessive refund is Phase 1.1"
— yet the same document's Business Rules, Error Scenarios and Acceptance Criteria sections all
describe `EXCESSIVE_REFUNDS` gating (F6) as active, testable Phase 1 behavior. This key does not
resolve which reading is correct. F6 stays a registered finding because the spec pack's own ACs
describe it as testable, but if a sharp participant notices the phasing contradiction and asks
about it, that is exactly correct instinct — the right answer is "good catch, that's a real
ambiguity in the source spec, escalate it to Mastercard rather than assume either reading," not
a reason to mark them wrong for registering F6.

## Smallest-diff remediation outline

### F1 — Sensitive data leak

**F1's scope on the offline path is LOGS ONLY. Two log lines, no response-body change.**

- `RefundService.processOfflineRefund`: stop logging the full `RefundRecord` (which carries
  `authorizationCode` in cleartext) at INFO — log only non-sensitive identifiers
  (`transactionId`, `status`). Stop logging the raw `request` object in the failure-path
  `catch` block — log `transactionId` only there too.
- **That is the whole fix.** The offline *response* legitimately still returns the
  authorization code afterwards, and the reference solution does exactly that. Do not let a
  participant (or a model) extend F1 into nulling the offline response — see the boxed note
  under "Exact secure behaviors the Stage 3 tests must assert" for why that would make a
  correct test permanently red.
- **Trap to watch:** a participant who fixes the success-path log line but leaves the
  failure-path log line (or vice versa) has "correctly solved the wrong problem" — both sinks
  must be fixed, not just the first one found. `pr-reviewer` in fresh context should catch a
  partial fix; the documented fallback prompt below exists for the case where it doesn't on the
  first pass. Note the two sinks are both **logs**; there is no third sink on this path (no
  audit file exists in this codebase).
- The one literal non-negotiable in the spec pack — the authorization code nulled from
  *online-refund retrieval* unless the return-authorization-data toggle is ON — is a **separate
  acceptance criterion of the `processOnlineRefund()` build task**, not something F1's fix
  satisfies and not something F1's fix should reach into. Don't let a participant think fixing
  F1's two log lines also means the online-path toggle behavior is handled; it isn't, until
  they build it in the second half of Stage 4.

### F2 — Incorrectly solving the right problem (idempotency)

- `RefundService.processOfflineRefund`: before inserting, call
  `refundRecordDao.findByIdempotencyKey(request.idempotencyKey())`. If present, return
  `RefundDecision.Declined("409 Conflict...")` (or an equivalent decline signal the controller
  maps to 409) instead of inserting a second record.
- **Trap to watch:** a fix that checks for an existing record but still inserts a new one
  "just in case" is not a fix — the whole point is *no second record*, not just *a different
  response*.

### F8 — Layering violation (build-blocking)

- Add a `voidRefund(RefundRequest)` method to `RefundService` that does the privilege check
  (`REFUND_EXPIRY`... no — `REFUNDS` privilege check) and calls `refundRecordDao.markVoided(...)`.
- `RefundController.voidRefund`: remove the `RefundRecordDao` field and constructor parameter
  entirely; delegate to `refundService.voidRefund(request)`, catching the privilege-denial
  signal and mapping it to 403.
- **How this surfaces:** `mvn verify` fails with an ArchUnit message naming the rule
  ("no classes that reside in a package '..api..' should depend on classes that reside in a
  package '..repo..'") the moment a participant touches the file — they don't have to notice
  this by eye. `tests/test_seeded_findings.sh`'s F8 check is a fast pre-check of the same fact
  and will flip from pass to fail once this is fixed — that's expected, not a bug in the test
  suite (see that test's own inline comment).

### F6 — live trap during the `processOnlineRefund()` build (not a standalone fix)

The real spec pack's own planted-wrinkles section tags the excessive-refund privilege gate as a
Lab 1 catch, same tier as F1-F4 — but it is **not** a remediation target on its own; it's a live
trap inside the Stage 4 online-refund build. Watch for a naive `processOnlineRefund()`
implementation that never checks `EXCESSIVE_REFUNDS` before approving a refund above the
captured amount. If nobody on the team raises it, that's fine — it stays registered as F6,
backlog, same as before. If a participant's build accidentally *does* handle it correctly,
that's a bonus, not an expectation.

### F12, F13, F14, F15 — spec rules the shipped path simply never implements

These four are seeded by **omission**, not by wrong code, and they are all in
`RefundService.processOfflineRefund` (inline comments there name each one). All four are
**backlog**: register them, do not fix them, and do not let them expand Stage 4's scope.

| | The rule, from the spec pack | Why it is its own finding |
|---|---|---|
| F12 | "`REFUNDS` — required for all refunds"; error table: "Missing `REFUNDS` privilege -> Rejected (403)" | Distinct from **F6**. F6 is the `EXCESSIVE_REFUNDS` gate on the above-captured-amount path; F12 is the base gate that should reject *every* refund from a merchant without `REFUNDS`. A group that finds one often assumes it has found the other — worth separating out loud. |
| F13 | "Currency must equal the original order currency"; error table: "Currency mismatch -> Rejected" | The inbound `paymentCurrency` is written straight to the record and never compared to anything. |
| F14 | "Voided transactions cannot be refunded"; error table: "Target transaction voided -> Rejected" | Nothing looks up the target transaction's status, so a `VOIDED` record can be refunded. Note the irony worth pointing out: F3's out-of-scope Void endpoint will happily mark a record `VOIDED`, and nothing then stops it being refunded. |
| F15 | "Amount must be positive and a valid ISO currency" (business rules); Mastercard Eng Std 5.1–5.3, "positive input validation... deny-list is not acceptable" | Distinct from F13 -- F13 is currency *matching the original order*; F15 is amount/currency being *well-formed at all*. A negative amount or a garbage currency string is accepted and processed today. |

**Why these are easier finds than F5, and what that means for the Stage 1 yield.** Each one is
a line in the spec with no counterpart in the code. Hand Claude Code the spec and ask it to
compare rule-by-rule against `RefundService` and all four come out reliably. That is exactly
what makes them *good* backlog findings and a *bad* proxy for skill — F5 remains the one that
requires noticing what the spec does **not** say. If a group registers F12-F15 and misses F5,
they have done the easy majority, not the hard part.

### F3's overlooked second half — worth a mention, not a separate finding

`voidRefund()`'s missing-`REFUNDS`-privilege path throws `IllegalStateException`, mapped to 403
by the controller. Mastercard's own standard states plainly: "business logic failures are not
exceptions... don't throw exceptions for expected business outcomes." The refund paths get this
right (`RefundDecision` is a sealed, structured outcome type, never an exception for a declined
refund) — `voidRefund()` doesn't follow the same pattern. This is folded into F3 rather than
given its own number: F3's whole point is "this endpoint shouldn't exist," and the reference
solution deliberately leaves it exactly as seeded rather than polishing code that's registered
as out-of-scope. Mention it if a sharp group asks why `voidRefund()`'s error handling looks
different from the refund paths' — don't volunteer it.

## Exact secure behaviors the Stage 3 tests must assert

**Slice 1 (F1 — sensitive data), 2-3 tests. LOGS ONLY on the offline path:**
- No `authorizationCode` value appears in the `RefundService` **log output** (INFO level,
  success path) for a processed offline refund.
- No `authorizationCode` value, and no dump of the whole `RefundRequest`, appears in the
  `RefundService` **log output** (ERROR level, `catch` block) for a failed offline refund.

> **Do not have them assert the offline *response body* is scrubbed — it is not, and it should
> not be.** The spec pack's non-negotiable is scoped precisely: the authorization code is nulled
> out of retrieval responses **for online refunds**, unless the return-authorization-data toggle
> is ON. Nothing in the spec asks the offline response to drop it, `RefundDecision.Approved`
> carries it by design, and the reference solution
> (`reference/RefundService.solved.java`) returns it on the offline path *after* a fully correct
> F1 fix. Verified live, not reasoned about: booting the app and posting to
> `POST /card-payments/{card_payment_gateway_id}/refunds` returns
> `{"transactionId":...,"amountMinor":...,"authorizationCode":"AUTH-…"}`. A test written to
> assert the offline response is scrubbed would stay **red forever** after the correct fix,
> which directly contradicts this lab's own "red before, green after" promise. If a group's
> Claude Code proposes that assertion, that is itself a good live teaching moment — the model
> generalised a real rule past its stated scope.
>
> The online-path rule is real, and it is tested — but it belongs to the
> `processOnlineRefund()` build task in Stage 4, not to F1's slice. See the note under F1 in
> the remediation outline above.

**How to assert on log output:** Spring Boot's `OutputCaptureExtension` — already on the
classpath via `spring-boot-starter-test`, no new dependency, and the unknown-dependency guard
should fire if anyone proposes adding a logging-test library instead:

```java
@ExtendWith(OutputCaptureExtension.class)
class RefundLoggingTest {
    @Test
    void offlineRefundDoesNotLogTheAuthorizationCode(CapturedOutput output) {
        RefundDecision decision = refundService.processOfflineRefund(
                RefundRequestFixtures.offlineRefund().build());
        String authCode = ((RefundDecision.Approved) decision).authorizationCode();
        assertThat(output).doesNotContain(authCode);   // the log must not carry it
        assertThat(authCode).isNotNull();              // the response legitimately still does
    }
}
```

That second assertion is worth insisting on: it pins the scope of the finding, so a participant
who "fixes" F1 by nulling the field out of the offline response too breaks a test rather than
quietly shipping an unrequested behaviour change.

**Slice 2 (F2 — idempotency), 2-3 tests:**
- A retried `POST /card-payments/{card_payment_gateway_id}/refunds` with the same
  `idempotencyKey` is declined (mapped to 409), not processed as a new refund.
- Exactly one `RefundRecord` exists for that `idempotencyKey` after two identical requests.

Both slices should build their request objects with
`com.mc.pgs.refunds.support.RefundRequestFixtures` rather than assembling the nested
`amounts`/`merchantOrder`/`wsApiSupport` structure by hand — the contract shape is faithful to
the real PGS API, which makes it verbose, and none of that verbosity is what Stage 3 is
teaching.

Both slices must be **red** before any Stage 4 fix, and **green** immediately after their
corresponding slice is remediated. `ArchitectureIT` (F8) is *also* red at this checkpoint and
has been since a fresh clone — but a plain `mvn verify` invocation will only ever **report
two** failures here, not three: Maven halts at the first failing phase (`test`/surefire), so it
never reaches the later `verify`/failsafe phase where `ArchitectureIT` lives once the two new
unit tests are also red. This is a real, confirmed Maven behavior, not a lab bug — brief
facilitators on it explicitly, since "why does it only show two, I was told three" is exactly
the kind of thing that reads as unpreparedness live if nobody's ready for the question.

**To see all three failures together in one command:** `mvn verify -Dmaven.test.failure.ignore=true`.
Verified directly, not assumed: this tells surefire not to halt the build on a test failure, so
Maven actually continues on to the failsafe phase and reports `ArchitectureIT`'s failure too —
you'll see all three `[ERROR] ... FAILURE!` blocks in the output. **The catch, worth stating out
loud before anyone runs it**: the build's final line still says `BUILD SUCCESS`, because that's
literally what "ignore" means to Maven — it did not treat the failures as build-halting, it did
not make them pass. Read the `[ERROR]` lines above the final line, not the final line alone, or
this trades one confusing moment for a different one. (An earlier version of this section
documented `-Dtest=ArchitectureIT -DfailIfNoTests=false -Dsurefire.skip=true` — that command
does print the ArchUnit failure, but for the wrong reason the doc claimed: `-Dsurefire.skip`
isn't a real Maven property, and the command actually works by making *surefire itself* pick up
the off-convention `*IT` class via `-Dtest=`, never touching failsafe at all — confirmed via
`mvn help:describe` and by reading the console output, which says `surefire:test`, not
`failsafe:integration-test`. Caught on a fresh re-review; corrected here.)

## Mandatory Stage 1→2 spot-check — the rubric cannot substitute for this

`.claude/rubrics/finish-the-refund.rubric.yaml` checks that `RISK_REGISTER.md` looks like a
real, table-shaped, sixteen-row register citing real filenames, with each finding on its own
well-formed row (a single line crammed with every keyword scores 64/136 — below the 70-point
pass threshold — confirmed in `grade_repo.py --self-test`, re-verified after F15/F16 were
added). It still cannot check that a row was
actually *investigated* rather than copied from this document's own F1–F16 table above (which
participants correctly have access to — `AGENTS.md` states the same table, since naming the
findings is part of the teaching, not a secret). Confirmed directly: a fabricated-but-correctly-
shaped register, assembled in a few minutes from `AGENTS.md`'s own content with zero real code
analysis, passes every automated content check at full marks. This is not a gap the DSL can
close — the correct answer looks identical whether a participant found it or copied it, and a
journey-log-based check strong enough to tell the difference would depend on hook-data-delivery
behavior that hasn't been independently confirmed working end-to-end (see the plugin's own known
issues) — building a *required, scored* check on top of that risk is worse than not building it,
since it could silently fail legitimate participants if that infrastructure turns out to be
broken. This is exactly why "the facilitator's live spot-check is the actual backstop, not the
rubric alone" is stated as a cross-lab principle, not lab-specific advice — treat the line below
as a mandatory action, not optional colour:

**Before a group moves from Stage 1 to Stage 2, pick 3 of their 16 `RISK_REGISTER.md` rows —
mix a "Fix" target (F1 or F2) with at least one backlog item, and prefer F5 or one of F12-F15 as
the third — and ask the group to show you the actual line(s) of code the row cites.** For
F12-F15 the honest answer is "there is no line, that's the point", so ask instead which line of
the spec the code fails to honour; a group that found it can point at the spec in seconds. A group that found it themselves can do this in seconds
and usually wants to, since they're proud of the catch. A group that copied the table cannot do
this convincingly, and it surfaces immediately, before the group has invested another hour
building on an unearned register. This costs under two minutes per group and is the only control
in this lab that actually closes the gap the rubric structurally cannot.

## Grading integrity — the two checks that run outside `/grade`

`/grade` (and its plugin-free equivalent, `python3 .claude/scripts/grade_repo.py`) is fast and
deterministic, and it is a backstop, not the whole control. Two further checks exist. Neither is
scored; both are yours to run.

### The F1 leak-reintroduction check — is their test a real test?

```bash
python3 .claude/scripts/anti_gaming_check.py
```

Run it after Stage 4. It copies the repo to a throwaway directory, **puts the F1 leak back**,
and re-runs the group's own F1 test against it.

- Test goes **red** with the leak restored -> the test genuinely detects the leak. Exit 0.
- Test stays **green** with the leak restored -> the test never detected anything. Exit 1.

This closes a gap nothing else can. A test that asserts nothing goes green after the fix exactly
like a real one does, writes an identical `FIXES.md` row, and scores full marks. Verified
directly during this build, not assumed: a class named `RefundLoggingTest` whose only assertion
is `assertThat(true).isTrue()` passes `mvn test` on correctly-fixed code, and this check catches
it while every content check misses it.

**If it fails, do not just report the number.** Restore the leak in front of the group, run
their test, and let them watch it stay green. Then ask what the test was for. That is a better
two minutes than any amount of explaining, and it generalises past this lab: a test you have
never seen fail is not evidence of anything.

Pass `--test <ClassName>` if the group named their test something the auto-detection misses, and
`--keep-temp` to inspect the mutated copy.

### F5 seed integrity — did they escalate, or did they quietly default?

This one **is** wired into the rubric, as part of the `f5-registered-and-escalated` criterion.
The criterion is an `all_of:` of two things: the register row saying "escalated", **and**
`seed_intact:f5-refund-expiry`, which asserts the `REFUND_EXPIRY` block in `RefundPrivilege.java`
is byte-for-byte what shipped (fixture: `.claude/fixtures/f5-refund-expiry.json`, which also
scans `application.yml` for a smuggled-in window value).

Why it needed both halves: a participant who invents a 180-day window **and** writes a tidy
"escalated" row used to score the full 8 points for doing precisely the thing the lab exists to
prevent. Now they score zero for F5. Confirmed in `grade_repo.py --self-test`, which grades
exactly that scenario.

### What neither check closes, stated plainly

A **fabricated** register — sixteen well-formed rows copied out of `AGENTS.md`'s own finding
table with no code analysis behind them — still scores full marks. That is not fixable with
more matching, because a correct row looks identical whether it was earned or copied. The
mandatory Stage 1->2 spot-check above is the control for it. Treat it as load-bearing.

## What's realistic in Stage 1

We do not expect all sixteen findings found unaided in 25 minutes, and **the 25-minute budget
does not move** — the yield changes, the clock does not. The honest shape:

- **~2 found with their own eyes**, before Claude Code is involved — submit the same refund
  twice (two records exist), open the log (authorization code in cleartext).
- **~11-12 surfaced by Claude Code** when prompted for a file-by-file review, and specifically
  when prompted to compare the code against the spec. This number went up from ~6-7 when
  F11-F14 were added, and again when F15/F16 were added, and the reason is worth knowing rather
  than guessing at: F12, F13, F14 and F15 are straightforward spec-comparison findings — a rule
  is stated in `specs/refunds-s2i-phase1.spec.md` (or, for F15, Mastercard's own Eng Std 5.1-5.3)
  and has no counterpart in `RefundService` — so they surface reliably the moment a group hands
  Claude Code the spec alongside the code. F11 is similar, one look at `RefundHealthIndicator`;
  F16 similarly surfaces the moment someone greps for where `ENABLE_REFUND_REQUESTS` or
  `SUPPORT_EXTENDED_REFUNDS` are actually used and finds nothing. None of them need more minutes;
  they need the right prompt, which the stage's instructions already give. **F5 is the exception
  and stays the exception** — it is a *silence* in the spec, not a mismatch with it, and no
  amount of spec-vs-code comparison surfaces it.
- **2-3 decoys deliberately surfaced and rejected** — e.g. "the H2 store is in-memory, this
  won't survive a restart" (true, but it's a lab fixture, not a finding), "no rate limiting on
  the refund endpoints" (a real concern, but a different backlog item, not seeded here),
  "`merchantId` isn't format-validated" (sounds sensible; the spec doesn't ask for it).
  Rejecting these takes the same muscle as finding F5.
- **F5 is deliberately hard.** An AI review won't flag it — the code looks perfectly
  reasonable. You only catch it by noticing the spec defines every other privilege's behavior
  except this one's threshold value. If a group finds it, call it out loudly. If nobody does,
  reveal it in the Stage 1 debrief — the reveal is itself the lesson.

## Failure-mode traps and where they bite

| Trap | Where it's designed to bite | What should catch it |
|---|---|---|
| Hallucination / invented dependency | A participant asks Claude Code to "add a PAN-masking library" — none exists on this path (F4 is the pre-planted version of the same trap) | `payments-guardrails` rule (from the plugin) + the plugin's unknown-dependency awareness |
| Correctly solving the wrong problem | Fixing F1's success-path log but leaving the failure-path log (or vice versa); or building `voidRefund()` out further instead of just registering F3 | `pr-reviewer` in fresh context, checking the full finding, not just the symptom noticed |
| Sycophancy | An in-session self-review of a fix, run in the same context that wrote it, says it looks good | `pr-reviewer` in fresh context, structurally unable to Write/Edit, doesn't inherit the authoring session's confidence |
| Incorrectly solving the right problem, live | A naive `processOnlineRefund()` that checks `TOGGLE_ENABLE_ONLINE_REFUND` but forgets to null the authorization code on retrieval — passes a happy-path test, fails the spec's stated non-negotiable | A test asserting the non-negotiable explicitly, or `pr-reviewer` reading the spec's actual wording, not just the happy path |
| Scope creep | The agent offers to write the settlement leg while building the online path | Should be declined and noted — DCF/settlement is explicitly out of scope (`specs/OUT_OF_SCOPE.md`) |

**Documented Stage-4 fallback prompt**, if `pr-reviewer` passes a fix clean on the first try and
the participant believes they're done: re-run it pointed explicitly at the specific sink —
*"Does the offline-refund failure log path still include the raw request or the authorization
code anywhere? Check both the success log line and the catch block separately."*

## Expected green/red state at each checkpoint

| Checkpoint | `BaselineTest` | `ArchitectureIT` (F8) — true state | `ArchitectureIT` — reported by a single `mvn verify` | Slice 1 (F1) | Slice 2 (F2) | Notes |
|---|---|---|---|---|---|---|
| Fresh clone | green (`mvn test`) | **red** | **red** | doesn't exist yet | doesn't exist yet | `mvn test` is green; `mvn verify` fails only on ArchUnit — nothing earlier is red yet, so it's reached and reported |
| End of Stage 2 | green | red | red | doesn't exist yet | doesn't exist yet | Plan written, not executed |
| End of Stage 3 | green | **red (unchanged)** | **not reached — verify reports 2, not 3** | **red** | **red** | F8 is still genuinely red; Maven just never gets there in one run once the two new slices are also red. See the note above the checkpoint table for the isolating command. |
| Mid Stage 4 (after F1 fix) | green | red | **not reached — F2's slice is still surefire-red** | **green** | red | F2 and F8 not yet touched; verify still stops at surefire, same phase-ordering reason as Stage 3 |
| Mid Stage 4 (after F2 fix) | green | red | red | green | **green** | Surefire is fully green now, so `mvn verify` finally reaches failsafe and reports F8 alone |
| End of Stage 4 (F8 fixed, online path built) | green | **green** | green | green | green | `mvn verify` fully green |
| End of Stage 6 | green | green | green | green | green | Gates reviewed, `SECURITY.md` complete |

A participant whose `BaselineTest` ever turns red as a side effect of a fix has broken scope —
it only exercises benign, already-correct behavior and should never be touched.
