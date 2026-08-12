# Payments Guardrails

Non-negotiable rules for any code that touches cardholder data, authorization decisions, or payment state. These apply regardless of what a prompt asks for — if a request conflicts with a rule below, follow the rule and say so.

## 1. Cardholder data never leaves the boundary unmasked

- **PAN (primary account number) and CVV must never appear in:** log output (any level), response bodies, response headers, exception messages/stack traces, or any persisted store that isn't the authorized cardholder-data store.
- If a masking/tokenization utility already exists in the codebase (e.g. a `PanTools`/`mask()`-style helper), it must be used on every path that touches a PAN — not just the ones a fix happens to touch. Grep for all read/write/log sites of the field before declaring a fix complete.
- "I removed it from the response" is not sufficient if it is still written to a log or an audit file. A fix must be verified against **every** sink, not the first one found.

## 2. Authorization must fail closed

- A missing, blank, expired, or malformed bearer token must result in denial — never a default identity, never an implicit role, never "admin" as a fallback.
- Every admin-scoped endpoint must explicitly require an admin-scoped credential. The absence of an explicit check is a finding, not a neutral default.
- Privilege must never be inferred from the shape of the request (e.g., "this looks like an admin call, so treat it as one").

## 3. Idempotency is a correctness requirement, not an optimization

- Any endpoint that creates a hold, charge, or state-mutating side effect must be safe to retry. An `idempotencyKey` (or equivalent) must be honored, not merely accepted and ignored.
- Under concurrent requests, a check-then-act pattern without synchronization is a race condition, not an edge case — treat "two simultaneous retries create two holds" as a real, reportable finding.

## 4. No invented dependencies or APIs

- Before proposing or using any library, class, method, or annotation, confirm it actually exists in this codebase's declared dependencies (`pom.xml`) or the relevant framework's real API surface. Plausible-sounding names are not evidence — e.g. there is no Spring built-in "PAN masker," and no `com.mastercard:pan-vault` artifact exists anywhere.
- If you are not certain a dependency or API exists, say so explicitly and verify (check `pom.xml`, check the framework's actual documentation) before using it. Do not silently proceed on a plausible guess.

## 5. Smallest possible diff

- A remediation should touch only what the finding requires. Do not refactor, rename, or "clean up" adjacent code in the same change — it makes the diff harder to review against the finding's acceptance criteria and increases the chance an unrelated regression slips through.

## 6. Backlog findings stay backlog findings

- Only fix what the current stage's plan explicitly targets. Findings that are registered but out of scope for this pass must be left exactly as documented — do not "helpfully" fix them, and do not silently leave them undocumented either.
