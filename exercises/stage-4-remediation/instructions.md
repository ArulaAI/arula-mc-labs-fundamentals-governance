# Stage 4 — Remediation (top 2 only)

**Goal:** Implement the fixes for **V1 and V2 only** — the exact scope named in
`.claude/lab.json`'s `targets` field — each one verified by its own security test turning
green, and each one passed through fresh-context review before you consider it done. V3
and every hygiene-backlog item stay `Open` in `RISK_REGISTER.md`; this stage does not touch
them, even if `plan.md` happens to describe a fix for them.

## Steps

For the V1 and V2 steps in `docs/plans/plan.md` only, in order:

1. Implement the smallest change that satisfies the step and turns its security test green
   (`.claude/rules/payments-guardrails.md` §5 — smallest possible diff).
2. Run `mvn test`. The targeted security test must now pass. `BaselineTest.java` and every
   previously-fixed security test must still pass.
3. Run `mvn verify` to trigger the quality gates (`.claude/hooks/quality-gates.sh`). Review
   the gate output — non-blocking doesn't mean ignorable; a `WARN` or `FAIL` here is a
   finding, not noise.
4. Invoke `code-to-spec-validator` in Mode B against this step's diff and the finding's
   acceptance criteria.
5. Invoke `pr-reviewer` against the diff. Per `.claude/rules/ai-use-policy.md` §2, do not
   pre-bias its prompt with your own confidence in the fix. Address every finding it
   raises — do not re-submit the same diff hoping for a different fresh-context outcome.

   ```text
   Review only the changes for remediation slice <1|2> against the payments-guardrails
   and coding-standards rules and the step <1|2> acceptance criteria. You are not the author.
   Do not soften findings. Confirm no PAN or CVV remains in logs, responses, headers or the store.
   Return findings for this slice only, with PASS or FAIL.
   ```

   Failure-mode watch: if slice 1's fix masks the PAN in the response but still logs it,
   the reviewer must fail it (correctly solving the wrong problem). If a fix references a
   nonexistent masker or dependency, the guardrail flags it (hallucination / invented
   dependency).
6. Once validator and reviewer both pass, add an entry to `FIXES.md` for this finding.

## Acceptance criteria

- [ ] V1 and V2 each have a corresponding `FIXES.md` entry — and nothing else does
- [ ] Both security-test slices are green; `BaselineTest.java` is still green
- [ ] Quality gates were run and reviewed after each fix (or at minimum, at the end)
- [ ] `code-to-spec-validator` and `pr-reviewer` both ran against every fix, in fresh context
- [ ] V3 and every hygiene-backlog item are still `Open` in `RISK_REGISTER.md`, untouched
- [ ] No new dependency was introduced without confirming it exists in `pom.xml`

## Hand-off

Log each fix in `docs/workflow-tracker.md` as it lands: finding ID, validator verdict,
reviewer verdict, gate results.
