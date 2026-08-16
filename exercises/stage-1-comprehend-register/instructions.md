# Stage 1 — Comprehend and register

**Goal:** a registered, prioritized `RISK_REGISTER.md` with all ten findings — not just the ones
you plan to fix.

## Steps

1. **First, with your own eyes, no AI.**
   - Start the app (`mvn spring-boot:run`). Submit the same `POST /refunds/offline` request
     twice with the same `idempotencyKey` — two records exist instead of one 409.
   - Open the application log — the authorization code appears in cleartext.
   - Try `POST /void-refunds` — it answers, and per `specs/OUT_OF_SCOPE.md`, it shouldn't exist
     at all.
2. Read `specs/refunds-s2i-phase1.spec.md` and `specs/OUT_OF_SCOPE.md` in full.
3. **Then** direct-prompt Claude Code:
   ```text
   Review these files together: RefundController.java, RefundService.java,
   RefundPrivilege.java, PreRiskAssessmentClient.java, RefundRecordDao.java.
   For each file return a table: file | responsibility | key dependencies | hidden side effects.
   Do not suggest fixes. Do not create the risk register yet.
   ```
4. **Triage what comes back.** Confirm the real findings, reject anything plausible-but-out-of-
   scope with a stated reason (a couple of decoys are seeded on purpose — see the "what's
   realistic" note in this stage's `spec.md`), rank by severity.
5. Fill `RISK_REGISTER.md`, one row per finding, including backlog items. Cite the actual
   affected file for each row — a placeholder won't score.
6. **F5 is deliberately hard** (see `RefundPrivilege.java` and the spec's privilege section).
   Don't move on until your group has explicitly decided whether it found F5 or not — if not,
   your facilitator will reveal it at the debrief.

## Acceptance criteria

- [ ] All ten findings registered, each citing a real affected file
- [ ] At least 2 findings found before any AI involvement
- [ ] At least 2 decoys explicitly rejected with a stated reason
- [ ] F5's status (found or not) is explicit, not silently skipped

## Hand-off

`/hand-off` — cite `RISK_REGISTER.md` as this stage's artifact.
