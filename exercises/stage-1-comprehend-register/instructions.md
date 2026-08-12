# Stage 1 — Comprehend & Register

**Goal:** Understand the card-authorization service well enough to find its real
vulnerabilities yourself, and register every one you find — including ones you don't plan
to fix.

## Steps

1. Read the service source under `src/main/java/com/mc/auth/`:
   - `domain/` — `AuthRequest`, `AuthDecision`
   - `service/` — `AuthService`, `PanTools`
   - `api/` — `AuthController`, `AdminController`
   - `repo/` — `InMemorySessionStore`
2. For each file, ask: where does cardholder data (PAN, CVV) flow? Where are authorization
   decisions made, and what happens on a missing/invalid credential? What happens if the
   same request is retried?
3. Use Claude Code to help you read and trace — but the finding is yours to confirm, not
   Claude's to hand you. Per `.claude/rules/ai-use-policy.md` §1, a suggestion is an input
   to your judgment, not a conclusion to accept by default.

   ```text
   Review these files together: AuthController.java, AuthService.java,
   AdminController.java, InMemorySessionStore.java, PanTools.java.
   For each file return a table: file | responsibility | key dependencies | hidden side effects.
   Do not suggest fixes. Do not create the risk register yet.
   ```
4. For every issue you find — whether you plan to fix it this pass or not — add an entry to
   [`RISK_REGISTER.md`](../../../RISK_REGISTER.md) using its template: severity, location,
   description, impact, status `Open`.

   ```text
   Using the observed behavior and your review, complete RISK_REGISTER.md.
   For each finding: unique ID (V1, V2...), concise name, severity
   (Critical/High/Medium/Low), the most relevant OWASP Top 10 category,
   affected files, one-sentence impact, status Open.
   Only document findings supported by the current code and observed behavior.
   ```
5. Findings you decide are out of scope for this lab pass still get registered as `Open`
   backlog items — they do not get silently dropped (`ai-use-policy.md` §4,
   `payments-guardrails.md` §6).

Before step 3, it's worth actually running the service and observing the behavior firsthand
rather than only reading code: `mvn spring-boot:run`, then authorize with an empty bearer
token (approves as admin), `curl localhost:8080/admin/sessions` (unauthenticated dump),
note the PAN in the response and the `X-Card-PAN` header, retry the same authorization and
see a second hold. `Ctrl+C` when done.

## Acceptance criteria

- [ ] `RISK_REGISTER.md` has at least 3 findings with concrete file/line locations
- [ ] Each finding has a stated severity and impact, not just a description
- [ ] At least one backlog (out-of-scope) item is registered, not just fix-candidates
- [ ] Nothing has been changed in `src/main/java/` yet — this stage is read-only

## Hand-off

Add an entry to `docs/workflow-tracker.md` per `ai-use-policy.md` §5 before moving to
Stage 2: what you looked at, what Claude Code helped with, what you personally verified.
