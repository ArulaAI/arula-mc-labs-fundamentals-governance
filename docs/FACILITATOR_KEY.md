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
| F3 | `voidRefund()` answers on `POST /void-refunds` — Void is explicitly out of scope | High | Correctly solving the wrong problem | `RefundController.java` | Registered, left `Open` |
| F4 | `PreRiskAssessmentClient` called — spec has no pre-risk-assessment step on this path | Medium | Hallucinated dependency | `PreRiskAssessmentClient.java` | Registered, left `Open` |
| F5 | `REFUND_EXPIRY` privilege exists; the window's value is genuinely undefined in the spec pack | High | Unauthorised default if silently invented | `RefundPrivilege.java` | **Registered + escalated** — not the same status as backlog |
| F6 | No gate checking `EXCESSIVE_REFUNDS` on the excessive-refund path | High | Missing privilege gate | `RefundService.java` | Registered — **live trap during Stage 4**, see below |
| F7 | No correlation ID propagated end-to-end | Low (hygiene) | — | `RefundController.java` | Backlog |
| F8 | Controller depends on `RefundRecordDao` directly; privilege check lives in the controller | High | Layering violation | `RefundController.java` | **Remediated, mechanically** — `ArchitectureIT` fails `mvn verify` until fixed |
| F9 | Hardcoded downstream settlement-notify URL | Low (hygiene) | — | `RefundService.java` | Backlog |
| F10 | No `@ControllerAdvice` — inconsistent error shape vs. Spring's default | Medium (hygiene) | — | `RefundController.java` | Backlog |

**Only F1 and F2 are remediation targets this pass** (`.claude/lab.json` `targets`), plus
building `processOnlineRefund()`. **F8 gets resolved too, but mechanically** — `mvn verify`
genuinely will not go green until it's fixed, so participants don't have to find it by eye; the
build finds it for them. F5 is registered and escalated, which is a *different* status from the
plain backlog items (F3, F4, F6, F7, F9, F10) — a participant who lumps F5 in with ordinary
backlog, or worse, invents a default window value for it, has failed the lab's central lesson
even if F1/F2/F8 are all correctly fixed.

## Smallest-diff remediation outline

### F1 — Sensitive data leak

- `RefundService.processOfflineRefund`: stop logging the full `RefundRecord` (which carries
  `authorizationCode` in cleartext) at INFO — log only non-sensitive identifiers
  (`transactionId`, `status`). Stop logging the raw `request` object in the failure-path
  `catch` block — log `transactionId` only there too.
- **Trap to watch:** a participant who fixes the success-path log line but leaves the
  failure-path log line (or vice versa) has "correctly solved the wrong problem" — both sinks
  must be fixed, not just the first one found. `pr-reviewer` in fresh context should catch a
  partial fix; the documented fallback prompt below exists for the case where it doesn't on the
  first pass.
- This lab's F1 is deliberately broader than the one literal non-negotiable in the spec pack
  (which is specifically about the authorization code being nulled from *online-refund
  retrieval* unless a toggle is ON) — that specific rule is a separate acceptance criterion of
  the `processOnlineRefund()` build task, not something F1's fix alone satisfies. Don't let a
  participant think fixing F1's two log lines also means the online-path toggle behavior is
  handled; it isn't, until they build it in the second half of Stage 4.

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

## Exact secure behaviors the Stage 3 tests must assert

**Slice 1 (F1 — sensitive data), 2-3 tests:**
- No `authorizationCode` value appears in the `RefundService` log output (INFO or ERROR level)
  for a successful or failed offline refund.
- No PAN, CVV, or authorization-code substring appears anywhere in the `/refunds/offline`
  response body.

**Slice 2 (F2 — idempotency), 2-3 tests:**
- A retried `POST /refunds/offline` with the same `idempotencyKey` is declined (mapped to 409),
  not processed as a new refund.
- Exactly one `RefundRecord` exists for that `idempotencyKey` after two identical requests.

Both slices must be **red** before any Stage 4 fix, and **green** immediately after their
corresponding slice is remediated. The pre-existing `ArchitectureIT` failure (F8) is a third,
separate red at this checkpoint — three reds total, not two, until F8 is also addressed.

## What's realistic in Stage 1

We do not expect all ten findings found unaided in 25 minutes. The honest shape:

- **~2 found with their own eyes**, before Claude Code is involved — submit the same refund
  twice (two records exist), open the log (authorization code in cleartext).
- **~6-7 surfaced by Claude Code** when prompted for a file-by-file review.
- **2-3 decoys deliberately surfaced and rejected** — e.g. "the H2 store is in-memory, this
  won't survive a restart" (true, but it's a lab fixture, not a finding), "no rate limiting on
  `/refunds/offline`" (a real concern, but a different backlog item, not seeded here),
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

| Checkpoint | `BaselineTest` | `ArchitectureIT` (F8) | Slice 1 (F1) | Slice 2 (F2) | Notes |
|---|---|---|---|---|---|
| Fresh clone | green (`mvn test`) | **red** (`mvn verify` only) | doesn't exist yet | doesn't exist yet | `mvn test` is green; `mvn verify` fails only on ArchUnit |
| End of Stage 2 | green | red | doesn't exist yet | doesn't exist yet | Plan written, not executed |
| End of Stage 3 | green | red | **red** | **red** | Three reds total at this checkpoint — see note above |
| Mid Stage 4 (after F1 fix) | green | red | **green** | red | F2 and F8 not yet touched |
| Mid Stage 4 (after F2 fix) | green | red | green | **green** | F8 not yet touched |
| End of Stage 4 (F8 fixed, online path built) | green | **green** | green | green | `mvn verify` fully green |
| End of Stage 6 | green | green | green | green | Gates reviewed, `SECURITY.md` complete |

A participant whose `BaselineTest` ever turns red as a side effect of a fix has broken scope —
it only exercises benign, already-correct behavior and should never be touched.
