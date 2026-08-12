# Stage 3 — Failing Tests

**Goal:** Write tests that assert the *secure* behavior for each in-scope finding, and
confirm they fail against the current (vulnerable) code, before writing any fix.

## Steps

1. Create `src/test/java/com/mc/auth/SecurityTest.java`.
2. For each finding targeted in `docs/plans/plan.md`, write one test that asserts the
   secure behavior — e.g., for the cardholder-data finding, assert a response body/header
   does *not* contain the raw PAN; for the authorization finding, assert a missing bearer
   token is rejected, not treated as admin.

   Slice 1 (cardholder-data exposure):
   ```text
   Write 2 to 3 JUnit 5 + MockMvc tests asserting the SECURE behavior for plan step 1:
   - no PAN or CVV in the response body,
   - no X-Card-PAN response header,
   - no PAN or CVV written to target/auth-audit.log.
   Deterministic tests, follow existing conventions. Do not modify production code.
   ```

   Slice 2 (broken authorization):
   ```text
   Write 2 to 3 JUnit 5 + MockMvc tests for plan step 2:
   - a missing or blank bearer token is denied (authorization fails closed),
   - a normal user token is forbidden on /admin/reversals,
   - /admin/sessions requires admin.
   Deterministic. Summarize expected pass/fail. Do not modify production code.
   ```
3. Run `mvn test`. Every new security test must **fail** right now — that's the point.
   A security test that passes before any fix either isn't asserting the right thing, or
   the finding was already wrong. Investigate rather than moving on.
4. Do not modify `BaselineTest.java` — it stays green throughout the lab and must never
   turn red as a side effect of your fixes.

## Acceptance criteria

- [ ] `SecurityTest.java` exists with one test per in-scope finding from `plan.md`
- [ ] `mvn test` shows every new security test failing (red)
- [ ] `BaselineTest.java` still passes
- [ ] Each test asserts secure behavior, not current behavior — per
      `.claude/rules/coding-standards.md` §Testing

## Hand-off

Log in `docs/workflow-tracker.md`: which findings got tests, and confirmation each one is
currently red with a one-line reason why.
