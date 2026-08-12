# Lab Action Guide — Fundamentals & Governance

## Workspace setup

1. Clone this repo and open the **repository root** in Claude Code (`claude` from `arula-mc-labs-fundamentals-governance/`). Everything the cohort uses at runtime — subagents, commands, hooks, guardrail rules — is committed directly in `.claude/`. There is no separate plugin install step.
2. Confirm the harness loaded: the subagents `planner`, `code-to-spec-validator`, `pr-reviewer` are listed, and `/hand-off`, `/grade`, `/lab` are offered. The `payments-guardrails` and `ai-use-policy` rules load automatically for every file. Run `/lab` to confirm — it reports the lab id, remediation targets, rubric, and time budget straight from `.claude/lab.json`.
3. The terminal is at the app root (`pom.xml` is here). All `mvn` commands run from here. If the subagents or commands are missing, you opened a subfolder rather than the repo root — reopen at the root.

## Commands and how to run them

| Command | What it does | When to run |
|---|---|---|
| `/lab` | Reports lab id, remediation targets (`V1`, `V2`), rubric, and time budget from `.claude/lab.json` | Anytime, especially Stage 0 |
| `/hand-off` | Summarizes the stage just finished and appends a structured entry to `docs/workflow-tracker.md` | End of every stage |
| `/grade` | Runs `.claude/hooks/lab-grader.sh` against `.claude/fundamentals.rubric.yaml` and reports the grade card | Stage 6, after quality gates pass |

## The flow at a glance

| # | Stage | Min | Claude Code surface | Key artifacts |
|---|-------|-----|--------------------------------------|---------------|
| 0 | Context and the five failure modes | 15 | facilitator walkthrough; `payments-guardrails` and `ai-use-policy` rules | shared understanding of the five modes |
| 1 | Comprehend and register | 25 | direct prompt to Claude Code | green baseline demoed, `RISK_REGISTER.md` |
| 2 | Plan | 12 | `planner`, then `code-to-spec-validator` | `docs/plans/plan.md`, Critical first |
| 3 | Failing security tests (top 2) | 18 | direct prompt for JUnit 5 + MockMvc | two failing tests, red-proof |
| 4 | Remediation (top 2 only) | 25 | edit, then `pr-reviewer` (fresh context) | V1 and V2 fixed, registries updated, green |
| 5 | Secure-future guide | 10 | `planner` | `docs/secure-features-guide.md`, no code |
| 6 | Governance validation and reporting | 15 | quality gates, `/hand-off`, `/grade` | gates green, `SECURITY.md`, journey, grade |

**Total: 120 minutes.**

## Test model

Security tests assert the **secure** behavior, so they **fail before remediation**, and that failure is the evidence the vulnerability is real. Remediation turns them green. Do not write tests that lock in the current unsafe behavior. At the Stage 3 checkpoint, exactly two reds are expected and everything else stays green.

## Stage 0: Context and the five failure modes (15 min)

Facilitator frames the five failure modes and governed Claude Code usage, and confirms the harness loaded (run `/lab`). No code yet.

The five failure modes, so the room has a shared vocabulary before Stage 1: hallucination (inventing a dependency or API that doesn't exist), correctly solving the wrong problem (fixing the visible symptom while the real leak persists elsewhere), incorrectly solving the right problem (a fix that doesn't actually close the finding), self-congratulation in review (an in-session self-review tends to pass because the author already believes it's correct), and invented dependencies (a specific case of hallucination worth calling out on its own in a payments context — see `payments-guardrails.md` §4).

## Stage 1: Comprehend and register (25 min)

**Goal:** a green baseline you have run, and a prioritized `RISK_REGISTER.md`.

1. Verify green and run the app:
   ```bash
   mvn validate && mvn test && mvn verify
   mvn spring-boot:run    # open http://localhost:8080, then Ctrl+C
   ```
2. Observe the behavior: authorize with an empty bearer token (approves as admin); `curl localhost:8080/admin/sessions` (unauthenticated dump); note the PAN in the response and the `X-Card-PAN` header; retry the same authorization and see a second hold.
3. Comprehend the code. Prompt Claude Code:
   ```text
   Review these files together: AuthController.java, AuthService.java,
   AdminController.java, InMemorySessionStore.java, PanTools.java.
   For each file return a table: file | responsibility | key dependencies | hidden side effects.
   Do not suggest fixes. Do not create the risk register yet.
   ```
4. Fill `RISK_REGISTER.md`, one row per finding:
   ```text
   Using the observed behavior and your review, complete RISK_REGISTER.md.
   For each finding: unique ID (V1, V2...), concise name, severity
   (Critical/High/Medium/Low), the most relevant OWASP Top 10 category,
   affected files, one-sentence impact, status Open.
   Only document findings supported by the current code and observed behavior.
   ```
5. **End of stage:** run `/hand-off`.

## Stage 2: Plan (12 min)

**Goal:** an ordered, validated remediation plan, Critical first.

1. **Subagent `planner`:**
   ```text
   Using RISK_REGISTER.md, produce a remediation plan. For each step:
   target file(s), one-line fix, expected post-fix state, success criterion.
   Critical severity first, then High. Number steps in priority order.
   Save to docs/plans/plan.md.
   ```
2. **Subagent `code-to-spec-validator`:**
   ```text
   Validate docs/plans/plan.md against the payments-guardrails and coding-standards
   rules. Return pass or fail and the corrections required before Stage 3.
   ```
3. Confirm `docs/plans/plan.md` exists and passed. **End of stage:** `/hand-off`.

## Stage 3: Failing security tests, top 2 (18 min)

**Goal:** two tests that assert secure behavior and therefore fail now.

1. Tests for plan step 1 (cardholder-data exposure):
   ```text
   Write 2 to 3 JUnit 5 + MockMvc tests asserting the SECURE behavior for plan step 1:
   - no PAN or CVV in the response body,
   - no X-Card-PAN response header,
   - no PAN or CVV written to target/auth-audit.log.
   Deterministic tests, follow existing conventions. Do not modify production code.
   ```
2. Tests for plan step 2 (broken authorization):
   ```text
   Write 2 to 3 JUnit 5 + MockMvc tests for plan step 2:
   - a missing or blank bearer token is denied (authorization fails closed),
   - a normal user token is forbidden on /admin/reversals,
   - /admin/sessions requires admin.
   Deterministic. Summarize expected pass/fail. Do not modify production code.
   ```
3. **Checkpoint:** `mvn test`. Two reds expected, everything else green.
4. **End of stage:** `/hand-off`.

## Stage 4: Remediation, top 2 only (25 min)

**Goal:** fix plan steps 1 and 2 with the smallest diffs, one fresh-context review per slice. Leave every other Open finding — including V3 — as the documented backlog. `.claude/lab.json`'s `targets` field (`["V1","V2"]`) is the enforced scope for this stage; nothing else gets touched.

1. Fix plan step 1 (smallest change): stop writing PAN and CVV to logs and `target/auth-audit.log`, remove the PAN from the response and drop the `X-Card-PAN` header, stop persisting CVV. Make the step 1 tests pass. Do not touch unrelated code.
2. **Subagent `pr-reviewer`** (fresh context, no sycophancy):
   ```text
   Review only the changes for remediation slice 1 against the payments-guardrails
   and coding-standards rules and the step 1 acceptance criteria. You are not the author.
   Do not soften findings. Confirm no PAN or CVV remains in logs, responses, headers or the store.
   Return findings for this slice only, with PASS or FAIL.
   ```
   Failure-mode watch: if the fix masks the PAN in the response but still logs it, the reviewer must fail it (correctly solving the wrong problem). If the fix references a nonexistent masker or dependency, the guardrail flags it (hallucination or invented dependency).
3. Update registries: mark V1 Remediated in `RISK_REGISTER.md`, add a `FIXES.md` row, confirm the step 1 test is green.
4. Fix plan step 2: authorization fails closed when the token is missing or blank; remove the unconditional admin grant; require admin on `/admin/*`. Make the step 2 tests pass, smallest diff.
5. **Subagent `pr-reviewer`** on slice 2 (same instructions, step 2 criteria).
6. Update registries for V2; confirm green.
7. `mvn test`. All green except the untouched backlog (V3 and the hygiene items). **End of stage:** `/hand-off`.

## Stage 5: Secure-future guide (10 min)

**Goal:** describe the proactive controls to adopt next. No new code.

1. **Subagent `planner`:**
   ```text
   Write docs/secure-features-guide.md describing proactive controls to adopt next:
   a Spring Security filter chain with deny-by-default, PAN tokenization and vaulting,
   idempotency keys on authorization, per-PAN and per-merchant rate limiting for TPS
   spikes, structured audit logging for admin actions, and secure error handling.
   No code changes.
   ```

## Stage 6: Governance validation and reporting (15 min)

**Goal:** prove the final state and close the audit trail.

1. Run the gates:
   ```bash
   mvn verify          # JaCoCo plus the two security tests now green
   ```
   The quality-gates hook also runs a cardholder-data scan (no PAN or CVV in logs or responses), a secret scan, and the coverage report.
2. Update `SECURITY.md`: record the two controls added in the Security Controls table, and the remaining Open findings (V3 plus the hygiene backlog) in the Known Risks table.
3. Confirm `docs/workflow-tracker.md` has a `/hand-off` entry per stage.
4. Run `/grade` for a grade card.
5. Recap for the room: the direct-prompt comprehension versus the fresh-context review loop; the two traced fixes (register, plan, failing test, fix, fresh review, green); and the documented backlog (V3 plus hygiene items) that was registered, not fixed.

## Artifact checklist

| Artifact | Used in |
|---|---|
| `payments-guardrails` and `ai-use-policy` rules | 1, 2, 4, 5 |
| `planner` subagent | 2, 5 |
| `code-to-spec-validator` subagent | 2 |
| `pr-reviewer` subagent | 4 |
| journey recording and `/hand-off` | 1, 2, 3, 4, 6 |
| quality gates | 6 |
| `/grade` | 6 |
| `RISK_REGISTER.md` | 1, 4 |
| `FIXES.md` | 4 |
| `docs/plans/plan.md` | 2 |
| `docs/secure-features-guide.md` | 5 |
| `docs/workflow-tracker.md` | 1, 2, 3, 4, 6 |
| `SECURITY.md` | 1, 6 |
| `docs/FACILITATOR_KEY.md` | facilitator reference |

## Bonus (optional): coverage as governance evidence

Run `mvn verify`, open `target/site/jacoco/index.html`, and discuss which authorization branches are proven versus the unverified backlog. No target percentage, and no new code. Coverage here is evidence of assurance, not a number to chase.

## See also

- [`AGENTS.md`](./AGENTS.md) — canonical rule + subagent reference
- [`README.md`](./README.md) — architecture note, prerequisites, generated artifacts
- [`docs/FACILITATOR_KEY.md`](./docs/FACILITATOR_KEY.md) — facilitator answer key (not for participants)
- [`exercises/`](./exercises/) — per-stage entry points with a predict-before-you-look hypothesis exercise
