# Stage 4 — Remediate and build

**Goal:** F1 and F2 fixed with the smallest diff each, F8 resolved (the build forces this), and
`processOnlineRefund()` built to spec. This is the largest block in the lab — the sycophancy
trap fires here.

## Steps

1. Fix F1 with the smallest diff (`payments-guardrails` rule, from the `workbench` plugin —
   smallest possible diff). Run `mvn test` — the F1 slice should now be green.
2. Invoke `pr-reviewer` in fresh context:
   ```text
   Review only the changes for the F1 remediation against payments-guardrails and the
   finding's full description. You are not the author. Do not soften findings.

   F1's scope on the offline path is LOGS ONLY: confirm no authorization code, and no
   dump of the whole request object, remains in RefundService's log output -- check the
   INFO success line and the ERROR line in the catch block SEPARATELY, since fixing one
   and missing the other is the expected partial fix.

   Scope check, both directions: the offline RESPONSE body legitimately still carries the
   authorization code -- the spec nulls it for ONLINE refund retrieval only. Flag it as a
   FAIL if the diff removes it from the offline response, that is an unrequested
   behaviour change, not part of this finding.

   Return PASS or FAIL.
   ```
   If it comes back clean on the first try and you believe you're done, **ask your facilitator
   for the Stage-4 fallback prompt** before assuming the reviewer is right.
3. Fix F2 with the same loop (fix → `mvn test` → fresh-context `pr-reviewer`).
4. `mvn verify` will still fail on ArchUnit until F8 is addressed — move the privilege-
   evaluation logic and the `RefundRecordDao` dependency out of `RefundController` and into
   `RefundService`. You don't have to hunt for this by eye; the build tells you.
5. Build `processOnlineRefund()`: honour `TOGGLE_ENABLE_ONLINE_REFUND`, null the authorization
   code from retrieval unless the return-authorization-data toggle is ON, do **not** write
   settlement records (DCF/settlement is downstream, out of scope per
   `specs/OUT_OF_SCOPE.md`).
   - **Live traps to watch for:** asking Claude Code for a PAN-masking library (none exists —
     the unknown-dependency check should flag it); an offer to write the settlement leg (out of
     scope, decline it); a naive build that skips the `EXCESSIVE_REFUNDS` check (reproduces F6
     live — note it, it's still backlog, not a new fix target).
6. Update `RISK_REGISTER.md` (status changes for F1, F2, F8) and `FIXES.md` (one row per fix,
   with the `pr-reviewer` verdict).

## Acceptance criteria

- [ ] F1 and F2 each have a `FIXES.md` entry with a fresh-context `pr-reviewer` PASS
- [ ] F8 resolved — `mvn verify` no longer fails on ArchUnit
- [ ] `processOnlineRefund()` built, honouring the toggle and the authorization-code rule, no
      settlement records written
- [ ] F3, F4, F5, F6, F7 and F9–F14 untouched — still exactly as registered in
      `RISK_REGISTER.md`
- [ ] No new dependency introduced without confirming it exists

## Hand-off

`/hand-off` — cite `FIXES.md` and the updated `RISK_REGISTER.md` as this stage's artifacts.
