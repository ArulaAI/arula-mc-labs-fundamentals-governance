# Stage 3 — Spec

## What this stage produces

Two new JUnit 5 test slices (F1, F2), both red, asserting intended/secure behavior.

## Done means

- `mvn test`: exactly two new failures, everything else green
- `mvn verify`: three failures total (the two new slices, plus the pre-existing `ArchitectureIT`
  failure for F8)
- No production code touched this stage — tests only
