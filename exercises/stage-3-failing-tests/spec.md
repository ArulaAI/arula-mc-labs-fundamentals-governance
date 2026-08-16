# Stage 3 — Spec

## What this stage produces

Two new JUnit 5 test slices (F1, F2), both red, asserting intended/secure behavior.

## Done means

- `mvn test`: exactly two new failures, everything else green
- `mvn verify`: exactly two failures reported (the two new slices) — Maven's default phase
  ordering means a single invocation stops at `test`/surefire before reaching the later
  `verify`/failsafe phase where `ArchitectureIT` (F8) lives, so its already-known red doesn't
  get re-reported in this run. That's expected, not a discrepancy.
- No production code touched this stage — tests only
