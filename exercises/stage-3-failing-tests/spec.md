# Stage 3 — Spec

## What this stage produces

`src/test/java/com/mc/auth/SecurityTest.java` — one JUnit 5 + MockMvc test per in-scope
finding from `docs/plans/plan.md`, each asserting secure behavior.

## Done means

- One test per targeted finding, traceable to a `plan.md` step
- `mvn test` shows every new test failing (red) against current code
- `BaselineTest.java` remains green
- No production code under `src/main/java/` has been modified yet
