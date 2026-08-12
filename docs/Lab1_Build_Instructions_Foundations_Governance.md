# Lab 1 Build Instructions: Foundations, Governance and the Five Failure Modes (Claude Code, payments)

**Audience:** Claude Code, building the lab, with a facilitator supervising.
**What this doc produces:** a ready-to-run lab consisting of a Java 21 + Spring Boot card-authorization service with a seeded, payment-grade security and governance challenge, the seeded registries and artifacts, the lab configuration for the `workbench` plugin, a facilitator answer key, and the participant action guide (`LAB_ACTION_GUIDE.md`) in the repo.
**Prerequisites:** Claude Code with the `workbench` plugin installed from the private marketplace; Java 21 (Temurin); Maven 3.9+. No other tooling. Everything the cohort uses at runtime comes from the `workbench` plugin.

> Reconcile plugin, subagent, hook and command names with the installed `workbench` version. This lab references the workbench pieces by role: subagents `planner`, `code-to-spec-validator`, `pr-reviewer`; commands `/lab`, `/hand-off`, `/grade`; rules `coding-standards`, `ai-use-policy`, `payments-guardrails`, `spec-template`; hooks `journey_record`, `quality_gates`; skills `spec-craft`, `sdet-architect`, `journey-recorder`, `lab-grader`.

---

## 1. Learning outcome and workbench pieces introduced

Cohort learns governed Claude Code usage on a real payments service, and learns to catch AI's five failure modes by hand before automating the catch. This lab **introduces the workbench plugin** and its governance parts.

- **Introduced here:** the plugin install itself; the governance rules (`ai-use-policy`, `payments-guardrails`); the `quality_gates` hook; the `journey_record` hook and `/hand-off`; the `pr-reviewer` subagent used for fresh-context review.
- **Used but introduced later:** `spec-craft` and `planner` appear lightly here and are the focus of Lab 2; `sdet-architect` appears lightly and is the focus of Lab 3.
- **The five failure modes** are seeded into the challenge on purpose: hallucination, correctly solving the wrong problem, incorrectly solving the right problem, self-congratulation in review, and invented dependencies.

---

## 2. The payments scenario

A global card issuer and network runs an **authorization service** that decides, in real time and at very high transactions per second, whether to approve a card authorization or a preauthorization hold. It handles primary account numbers (PANs), CVV, expiry, amount and merchant data, and it must never leak cardholder data, must fail closed on authorization, and must not double-hold funds on a retry.

The seeded service is functionally plausible but deliberately unsafe. The cohort comprehends it, registers the risks, plans, writes failing security tests, remediates the top two findings with the smallest possible diffs under fresh-context review, and closes the audit trail. The remaining findings are a deliberate, documented backlog.

---

## 3. Build the lab repo

Create a repository `lab-card-auth` with this shape:

```
lab-card-auth/
  pom.xml                         # Java 21, Spring Boot 3.3.x, spring-boot-starter-web, -validation, -test; JaCoCo
  src/main/java/com/mc/auth/
    AuthApplication.java
    api/AuthController.java        # POST /authorizations, POST /preauthorizations
    api/AdminController.java       # POST /admin/reversals, GET /admin/sessions
    domain/AuthRequest.java        # record: pan, cvv, expiry, amountMinor, currency, merchantId, idempotencyKey (nullable)
    domain/AuthDecision.java       # sealed interface Approved/Declined
    service/AuthService.java       # decision logic, holds, roles
    service/PanTools.java          # Luhn check, masking helper (present but unused on the leak paths)
    repo/InMemorySessionStore.java # holds and "audit" writes
  src/main/resources/application.yml
  src/test/java/com/mc/auth/BaselineTest.java   # one passing test (green baseline)
  RISK_REGISTER.md                # empty template, columns below
  FIXES.md                        # empty template
  SECURITY.md                     # reporting policy + Known Risks and Security Controls tables (to fill)
  docs/plans/.gitkeep
  docs/workflow-tracker.md        # empty; /hand-off appends here
  docs/FACILITATOR_KEY.md         # answer key (section 3.4)
  LAB_ACTION_GUIDE.md             # participant guide (section 5)
  .claude/                        # lab-local config that layers on the workbench plugin
    settings.json                 # enables quality_gates + journey_record hooks for this repo
    lab.json                      # lab id, rubric ref, top-2 targets
```

### 3.1 Stack and baseline
- Java 21. Use records for `AuthRequest`/`AuthDecision`, a sealed interface for the decision, and virtual threads enabled in `application.yml` (`spring.threads.virtual.enabled: true`) so the high-TPS framing is real.
- Spring Boot 3.3.x, `spring-boot-starter-web`, `-validation`, `-test`; JaCoCo wired into `verify`.
- `mvn validate`, `mvn test`, `mvn verify` are green on a fresh clone. `BaselineTest` asserts the context loads and a benign authorization returns a decision. Vulnerabilities surface through behavior, not build failure.

### 3.2 Seeded findings (generate the code so these are true)
- **V1 Critical, cardholder data exposure (PCI DSS, OWASP A02).** `AuthService`/`AuthController` log the full PAN and CVV at INFO and append them to `target/auth-audit.log`; the authorization response body includes the PAN and sets an `X-Card-PAN` response header; the CVV is persisted in `InMemorySessionStore`. `PanTools.mask()` exists but is not called on these paths.
- **V2 Critical, broken authorization (OWASP A01).** `/authorizations`, `/preauthorizations`, `/admin/reversals` and `/admin/sessions` all **fail open**: a missing or blank bearer token defaults to an authenticated `admin`. A normal user token can call `/admin/reversals` (privilege escalation). `GET /admin/sessions` returns the full session dump unauthenticated.
- **V3 High, non-idempotent authorization (double-hold).** When `idempotencyKey` is null or ignored, a retried authorization creates a second hold. Under concurrency there is a check-then-act race in `InMemorySessionStore`.
- **Backlog (do not fix in this lab):** no per-PAN or per-merchant rate limiting for TPS spikes, weak PAN validation (Luhn helper unused), naive expiry parsing, verbose stack traces leaked to clients, no audit record for admin actions.

### 3.3 Failure-mode traps (documented in the key, not in participant text)
- **Hallucination / invented dependency:** if a learner asks Claude to "use Spring's built-in PAN masker" or add a `com.mastercard:pan-vault` dependency, neither exists. The `payments-guardrails` rule and the `quality_gates` unknown-dependency check must flag this.
- **Correctly solving the wrong problem:** masking the PAN in the response while still writing it to `target/auth-audit.log`. The `code-to-spec-validator` (fresh context) checks the change against the finding's full acceptance criteria and catches the residual log leak.
- **Self-congratulation in review:** an in-session self-review will pass the change. The `pr-reviewer` subagent runs in a fresh context and does not.

### 3.4 `docs/FACILITATOR_KEY.md`
Include: the full finding list with severities and OWASP mapping; the two remediation targets (V1, V2) with the smallest-diff solution outline; the exact secure behaviors the Stage 3 tests must assert; the three failure-mode traps and where they bite; and the expected green/red state at each checkpoint.

### 3.5 Lab config for the workbench
- `.claude/lab.json`: `{ "id": "foundations-governance", "targets": ["V1","V2"], "rubric": "foundations.rubric.yaml", "minutes": 120 }`.
- Provide `foundations.rubric.yaml` for `lab-grader` scoring the objective items: registered all findings, plan ordered Critical first, two failing tests at the Stage 3 checkpoint, both targets green after Stage 4, no PAN/CVV in logs or responses, backlog left intact, `/hand-off` entry per stage.
- `.claude/settings.json`: enable the `quality_gates` and `journey_record` hooks for this repo.

### 3.6 Registry columns
- `RISK_REGISTER.md`: `ID | Name | Severity | OWASP | Affected files | Impact | Status`.
- `FIXES.md`: `ID | Change | Files | Test | Reviewer verdict | Date`.

---

## 4. Acceptance: the lab is built correctly when

1. Fresh clone: `mvn validate/test/verify` green; app runs on `http://localhost:8080`.
2. Behavior reproduces every seeded finding (empty-token authorization approves; `GET /admin/sessions` dumps unauthenticated; PAN appears in the response, the `X-Card-PAN` header and `target/auth-audit.log`; a retried authorization double-holds).
3. The workbench pieces resolve in the repo: subagents, `/hand-off`, `/grade`, and the two hooks are available with the plugin installed.
4. `lab-grader` can score a completed run from the journey file and produce the same score twice.
5. The facilitator key matches the seeded reality.

---

## 5. Participant Action Guide (write to `LAB_ACTION_GUIDE.md`)

### Workspace setup
1. Install the workbench plugin if you have not: `claude plugin install workbench@mastercard-workbench`. Open the **repository root** in Claude Code (`claude` from `lab-card-auth/`). The root `.claude/` plus the plugin is what makes the subagents, `/hand-off`, `/grade` and the guardrail rules available.
2. Confirm the plugin loaded: the subagents `planner`, `code-to-spec-validator`, `pr-reviewer` are listed, and `/hand-off` and `/grade` are offered. The `payments-guardrails` and `ai-use-policy` rules load automatically for every file.
3. The terminal is at the app root (`pom.xml` is here). All `mvn` commands run from here. If the subagents or `/hand-off` are missing, the plugin is not installed or you opened a subfolder; reinstall and reopen at the root.

### The flow at a glance

| # | Stage | Min | Claude Code surface (from workbench) | Key artifacts |
|---|-------|-----|--------------------------------------|---------------|
| 0 | Context and the five failure modes | 15 | facilitator walkthrough; `payments-guardrails` and `ai-use-policy` rules | shared understanding of the five modes |
| 1 | Comprehend and register | 25 | direct prompt to Claude Code | green baseline demoed, `RISK_REGISTER.md` |
| 2 | Plan | 12 | `planner`, then `code-to-spec-validator` | `docs/plans/plan.md`, Critical first |
| 3 | Failing security tests (top 2) | 18 | direct prompt for JUnit 5 + MockMvc | two failing tests, red-proof |
| 4 | Remediation (top 2 only) | 25 | edit, then `pr-reviewer` (fresh context) | V1 and V2 fixed, registries updated, green |
| 5 | Secure-future guide | 10 | `planner` | `docs/secure-features-guide.md`, no code |
| 6 | Governance validation and reporting | 15 | `quality_gates`, `/hand-off`, `/grade` | gates green, `SECURITY.md`, journey, grade |

### Test model
Security tests assert the **secure** behavior, so they **fail before remediation**, and that failure is the evidence the vulnerability is real. Remediation turns them green. Do not write tests that lock in the current unsafe behavior. At the Stage 3 checkpoint, exactly two reds are expected and everything else stays green.

### Stage 0: Context and the five failure modes (15 min)
Facilitator frames the five failure modes and governed Claude Code usage, and confirms the plugin loaded. No code yet.

### Stage 1: Comprehend and register (25 min)
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

### Stage 2: Plan (12 min)
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

### Stage 3: Failing security tests, top 2 (18 min)
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

### Stage 4: Remediation, top 2 only (25 min)
**Goal:** fix plan steps 1 and 2 with the smallest diffs, one fresh-context review per slice. Leave every other Open finding as the documented backlog.
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
7. `mvn test`. All green except the untouched backlog. **End of stage:** `/hand-off`.

### Stage 5: Secure-future guide (10 min)
**Goal:** describe the proactive controls to adopt next. No new code.
1. **Subagent `planner`:**
   ```text
   Write docs/secure-features-guide.md describing proactive controls to adopt next:
   a Spring Security filter chain with deny-by-default, PAN tokenization and vaulting,
   idempotency keys on authorization, per-PAN and per-merchant rate limiting for TPS
   spikes, structured audit logging for admin actions, and secure error handling.
   No code changes.
   ```

### Stage 6: Governance validation and reporting (15 min)
**Goal:** prove the final state and close the audit trail.
1. Run the gates:
   ```bash
   mvn verify          # JaCoCo plus the two security tests now green
   ```
   The `quality_gates` hook also runs a cardholder-data scan (no PAN or CVV in logs or responses), a secret scan, and the coverage threshold.
2. Update `SECURITY.md`: record the two controls added in Security Controls, and the remaining Open findings as Known Risks and Accepted (the backlog).
3. Confirm `docs/workflow-tracker.md` has a `/hand-off` entry per stage.
4. Run `/grade` (the `lab-grader` skill) against the journey file for a grade card and cohort roll-up.
5. Recap for the room: the direct-prompt comprehension versus the fresh-context review loop; the two traced fixes (register, plan, failing test, fix, fresh review, green); and the documented backlog that was registered, not fixed.

### Artifact checklist

| Artifact | Used in |
|---|---|
| `payments-guardrails` and `ai-use-policy` rules (plugin) | 1, 2, 4, 5 |
| `planner` subagent | 2, 5 |
| `code-to-spec-validator` subagent | 2 |
| `pr-reviewer` subagent | 4 |
| `journey_record` hook and `/hand-off` | 1, 2, 3, 4, 6 |
| `quality_gates` hook | 6 |
| `lab-grader` (`/grade`) | 6 |
| `RISK_REGISTER.md` | 1, 4 |
| `FIXES.md` | 4 |
| `docs/plans/plan.md` | 2 |
| `docs/secure-features-guide.md` | 5 |
| `docs/workflow-tracker.md` | 1, 2, 3, 4, 6 |
| `SECURITY.md` | 1, 6 |
| `docs/FACILITATOR_KEY.md` | facilitator reference |

### Bonus (optional): coverage as governance evidence
Run `mvn verify`, open `target/site/jacoco/index.html`, and discuss which authorization branches are proven versus the unverified backlog. No target percentage, and no new code. Coverage here is evidence of assurance, not a number to chase.
