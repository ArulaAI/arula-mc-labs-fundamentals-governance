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
3. Run `mvn verify`. Confirm it fails on **three** things at this checkpoint: the two new red
   slices, plus the pre-existing `ArchitectureIT` failure (F8) that's been there since a fresh
   clone. If you see a different failure count, stop and check with your facilitator before
   continuing — see `docs/FACILITATOR_KEY.md`'s checkpoint table (facilitators only).

## Acceptance criteria

- [ ] Two new test slices exist, asserting intended/secure behavior, not current behavior
- [ ] Both are red; `BaselineTest` and everything else stays green
- [ ] No production code was modified this stage

## Hand-off

`/hand-off` — cite the new test files as this stage's artifact, and the `mvn test`/`mvn verify`
output confirming the red state.
