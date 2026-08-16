# Stage 3 — Prove it's broken

**Goal:** two new red test slices, proving F1 and F2 are real — before touching any production
code.

## Steps

1. Direct-prompt Claude Code:
   ```text
   Write JUnit 5 tests asserting the INTENDED behavior:
   - no authorization code or PAN/CVV appears in any sink (response body, header, log,
     audit file) for a processed offline refund -- F1
   - a retried refund with the same idempotencyKey returns a decline/409 and creates no
     second record -- F2
   Deterministic tests, follow existing conventions. Do not modify production code.
   ```
2. Run `mvn test`. Confirm exactly the two new slices are red — everything else, including
   `BaselineTest`, stays green.
3. Run `mvn verify`. Confirm it fails, and confirm it reports **exactly two** failures — not
   three. This is not a discrepancy to chase down: Maven stops at the first failing phase
   (`test`/surefire), so a single `mvn verify` invocation never reaches the later
   `verify`/failsafe phase where `ArchitectureIT` (F8) lives once earlier tests are red. F8's
   red is real and unchanged — it's just not re-reported in this particular run. If you want to
   see it directly at this checkpoint, run
   `mvn verify -Dtest=ArchitectureIT -DfailIfNoTests=false -Dsurefire.skip=true` (skips the two
   known-red unit tests, runs only the ArchUnit check) — or just trust that it's still there,
   since nothing you did this stage touched it. If you see a failure count other than two, stop
   and check with your facilitator before continuing — see `docs/FACILITATOR_KEY.md`'s
   checkpoint table (facilitators only).

## Acceptance criteria

- [ ] Two new test slices exist, asserting intended/secure behavior, not current behavior
- [ ] Both are red; `BaselineTest` and everything else stays green
- [ ] No production code was modified this stage

## Hand-off

`/hand-off` — cite the new test files as this stage's artifact, and the `mvn test`/`mvn verify`
output confirming the red state.
