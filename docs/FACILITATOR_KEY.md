# Facilitator Key — Fundamentals & Governance

**Not for participants.** This is the answer key: the full finding list, the smallest-diff
remediation outline for the two in-scope targets, the exact secure behaviors Stage 3's
tests must assert, where the three failure-mode traps bite, and the expected green/red
state at each stage checkpoint.

## Full finding list

| ID | Name | Severity | OWASP | Affected files | Status this lab |
|---|---|---|---|---|---|
| V1 | Cardholder-data exposure | Critical | A02:2021 – Cryptographic Failures (PCI DSS) | `AuthService.java`, `AuthController.java`, `InMemorySessionStore.java` | **Remediated** (target) |
| V2 | Broken authorization (fail-open + privilege escalation) | Critical | A01:2021 – Broken Access Control | `AuthService.java`, `AuthController.java`, `AdminController.java` | **Remediated** (target) |
| V3 | Non-idempotent authorization (double-hold race) | High | A04:2021 – Insecure Design (unsynchronized check-then-act; facilitator call, not stated verbatim in the source instructions) | `InMemorySessionStore.java` | Registered, left Open — **not** in this pass's remediation scope |
| — | No per-PAN/per-merchant rate limiting | Medium (hygiene) | A04:2021 | (proactive control) | Backlog — proactive-controls guide only |
| — | Weak PAN validation (Luhn helper unused) | Low (hygiene) | — | `PanTools.java` (`isLuhnValid` never called) | Backlog |
| — | Naive expiry parsing | Low (hygiene) | — | `AuthRequest.java` (no format validation on `expiry`) | Backlog |
| — | Verbose stack traces leaked to clients | Medium (hygiene) | A09:2021 | `InMemorySessionStore.appendAuditLog` rethrows raw exception | Backlog |
| — | No audit record for admin actions | Medium (hygiene) | A09:2021 | `AdminController.java` | Backlog |

**Only V1 and V2 are remediated in this lab pass** (`.claude/lab.json` `targets`). V3 is a
real, registered, unaddressed finding — distinct from the hygiene backlog above, which are
proactive-control gaps rather than seeded vulnerabilities. A participant who tries to fix
V3 or any hygiene item in Stage 4 has scope-crept past the plan; that's a coachable moment,
not something to silently allow (`ai-use-policy.md` §4).

## Smallest-diff remediation outline

### V1 — Cardholder-data exposure

- `AuthService.authorize`: stop logging `pan`/`cvv` at INFO — either drop them from the log
  line entirely or route them through `PanTools.mask()` for the PAN and omit CVV outright
  (CVV must never be logged or persisted, masked or not — see `payments-guardrails.md` §1).
- `AuthController` (`authorize`, `preauthorize`): stop setting the `X-Card-PAN` header; stop
  returning the raw `pan` in the response body. `AuthDecision.Approved` currently carries
  `pan` — either drop the field or ensure only a masked form is ever populated into it.
- `InMemorySessionStore.appendAuditLog`: stop writing raw `pan`/`cvv` to
  `target/auth-audit.log` — mask the PAN via `PanTools.mask()`, omit CVV entirely. Also stop
  persisting raw CVV on `Hold` itself (`Hold.cvv()` should not retain it past the
  authorization call).
- **Trap to watch:** a participant who masks the response but leaves the log write (or vice
  versa) has "correctly solved the wrong problem" — `PanTools.mask()` must be applied on
  **every** sink (log, response body, response header, persisted store), not just the first
  one found. `code-to-spec-validator` and `pr-reviewer` should both catch a partial fix.

### V2 — Broken authorization

- `AuthService.resolveRole`: a missing or blank bearer token must be **denied**, not
  resolved to `"admin"`. The smallest correct change: throw/return a denial signal instead
  of the `"admin"` fallback; callers must actually check the result and reject rather than
  proceeding regardless.
- `AuthController` (`authorize`, `preauthorize`): must actually act on a denial from
  `resolveRole` (currently the return value is discarded) — reject with 401/403 rather than
  proceeding to `authService.authorize(request)` regardless of role.
- `AdminController.reverse`: must explicitly require the resolved role to equal `"admin"`
  before calling `sessionStore.reverseHold` — currently resolves a role and ignores it.
- `AdminController.sessions`: currently has **no** authentication/authorization check at
  all — must require an admin-scoped credential before returning the session dump.
- **Trap to watch:** a fix that makes `/authorizations` fail closed but leaves
  `/admin/sessions` wide open is incomplete — the finding covers all four fail-open sites
  named in the seeded-findings table (`AuthController` x2, `AdminController` x2), not just
  the first one a participant notices.

**Terminology note — "two reds" means two *slices*, not two literal JUnit methods.**
Each slice gets 2-3 individual test methods (so 4-6 total methods across both slices), but
the Stage 3 checkpoint's "two reds" refers to the two slices being collectively red — i.e.
`SecurityTest` reports failures in both the V1-slice group and the V2-slice group, not
literally exactly 2 failed test methods. If a participant or co-facilitator counts JUnit's
"X tests failed" number and gets 4, 5, or 6 rather than 2, that's expected, not a bug —
clarify this up front rather than letting it read as a discrepancy against this doc.

## Exact secure behaviors the Stage 3 tests must assert

**Slice 1 (V1 — cardholder-data exposure), 2-3 tests:**
- No PAN or CVV substring appears anywhere in the `/authorizations` response body.
- No `X-Card-PAN` response header is present.
- After a call, `target/auth-audit.log` (if it exists) contains no raw PAN or CVV digit run.

**Slice 2 (V2 — broken authorization), 2-3 tests:**
- A request to `/authorizations` (or `/preauthorizations`) with a missing or blank
  `Authorization` header is denied (4xx), not approved.
- A non-admin (any non-blank, non-admin-signaling) token on `/admin/reversals` is forbidden.
- `GET /admin/sessions` without an admin credential is denied, not a 200 with data.

Both slices' tests must be **red** before any Stage 4 fix, and **green** immediately after
their corresponding slice is remediated — not before, not delayed until both slices land.

## The three failure-mode traps and where they bite

| Trap | Where it's designed to bite | What should catch it |
|---|---|---|
| Hallucination / invented dependency | A participant asks Claude to "use Spring's built-in PAN masker" or add `com.mastercard:pan-vault` — neither exists | `payments-guardrails.md` §4 (rule text names the fake coordinate explicitly) + `.claude/hooks/quality-gates.sh`'s unknown-dependency gate (diffs `pom.xml` against a first-run baseline) |
| Correctly solving the wrong problem | Masking the PAN in the response while still writing it to `target/auth-audit.log` (or vice versa) | `code-to-spec-validator`, which checks the change against the finding's **full** acceptance criteria, not just the symptom the participant noticed |
| Self-congratulation in review | An in-session self-review of the fix, run in the same context that wrote it | `pr-reviewer`, which runs in a genuinely fresh context (`disallowedTools: Write, Edit, MultiEdit, NotebookEdit` — structurally cannot "fix while reviewing") |

## Expected green/red state at each checkpoint

| Checkpoint | `BaselineTest` | `SecurityTest` (slice 1) | `SecurityTest` (slice 2) | Notes |
|---|---|---|---|---|
| End of Stage 0 | green (not yet run this session, but was green on clone) | doesn't exist yet | doesn't exist yet | — |
| End of Stage 1 | green | doesn't exist yet | doesn't exist yet | Behavior demoed manually (curl), not via tests yet |
| End of Stage 2 | green | doesn't exist yet | doesn't exist yet | Plan written, not executed |
| End of Stage 3 | green | **red** | **red** | "Two reds" = both slices red (4-6 individual test methods total) — see the terminology note above |
| Mid Stage 4 (after slice 1 fix) | green | **green** | red | Slice 2 not yet touched |
| End of Stage 4 | green | green | **green** | Both targets green; V3 and hygiene backlog untouched |
| End of Stage 6 | green | green | green | `mvn verify` green, quality gates reviewed, `SECURITY.md` complete |

A participant whose `BaselineTest` ever turns red as a side effect of a fix has broken
scope — `BaselineTest` only exercises benign, already-correct behavior and should never be
touched.
