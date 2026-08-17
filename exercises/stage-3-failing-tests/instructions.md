# Stage 3 — Prove it's broken

**Goal:** two new red test slices, proving F1 and F2 are real — before touching any production
code.

## Steps

1. Direct-prompt Claude Code:
   ```text
   Write JUnit 5 tests asserting the INTENDED behavior:

   - F1, LOGS ONLY: no authorization code appears in RefundService's log output --
     neither the INFO success line nor the ERROR line in the catch block -- for an
     offline refund. Use Spring Boot's OutputCaptureExtension (already available via
     spring-boot-starter-test) with a CapturedOutput parameter; do not add a new
     dependency for this.
     Do NOT assert the offline RESPONSE body is scrubbed. The spec scopes
     authorization-code nulling to ONLINE refund retrieval only, so the offline
     response legitimately still carries it. Assert it is still present, to pin the
     scope of the fix.

   - F2: a retried refund with the same idempotencyKey returns a decline/409 and
     creates no second record.

   Build request objects with com.mc.pgs.refunds.support.RefundRequestFixtures --
   do not hand-assemble the nested amounts/merchantOrder/wsApiSupport structure.
   Deterministic tests, follow existing conventions. Do not modify production code.
   ```

   **Why F1's slice is logs-only.** The spec's non-negotiable is precise: the authorization code
   is nulled from retrieval responses **for online refunds**, unless the
   return-authorization-data toggle is ON. Nothing asks the offline response to drop it. A test
   asserting the offline response is scrubbed would still be red after a completely correct
   fix — which is not "proving it's broken", it's proving the test wrong. (The online-path rule
   is real and you will implement it in Stage 4 when you build `processOnlineRefund()`.) If
   Claude Code volunteers that assertion anyway, notice it: generalising a real rule past its
   stated scope is exactly the failure mode this stage exists to make visible.

   **Writing the request.** The request shape is faithful to the real PGS contract, so it is
   nested. `RefundRequestFixtures` gives you sensible defaults and only makes you state what
   your test is actually about:

   ```java
   RefundRequest first = RefundRequestFixtures.offlineRefund().idempotencyKey("idem-1").build();
   RefundRequest retry = RefundRequestFixtures.offlineRefund().idempotencyKey("idem-1").build();

   // for a MockMvc test: the path constants and the JSON body are both there
   mockMvc.perform(post(RefundRequestFixtures.PAYMENT_REFUND_PATH)
           .contentType(APPLICATION_JSON)
           .content(RefundRequestFixtures.offlineRefund().json()));
   ```
2. Run `mvn test`. Confirm exactly the two new slices are red — everything else, including
   `BaselineTest`, stays green.
3. Run `mvn verify`. Confirm it fails, and confirm it reports **exactly two** failures — not
   three. This is not a discrepancy to chase down: Maven stops at the first failing phase
   (`test`/surefire), so a plain `mvn verify` invocation never reaches the later
   `verify`/failsafe phase where `ArchitectureIT` (F8) lives once earlier tests are red. F8's
   red is real and unchanged — it's just not re-reported in this particular run. If you want to
   see all three together, run `mvn verify -Dmaven.test.failure.ignore=true` — this tells Maven
   not to halt on a test failure, so it continues on to failsafe and reports `ArchitectureIT`
   too. One catch: the final line will say `BUILD SUCCESS` even though three things failed —
   that's what "ignore" means to Maven, read the `[ERROR]` blocks above it, not the last line.
   If you see a failure count other than two on a plain `mvn verify`, stop and check with your
   facilitator before continuing — see `docs/FACILITATOR_KEY.md`'s checkpoint table
   (facilitators only).

## Acceptance criteria

- [ ] Two new test slices exist, asserting intended/secure behavior, not current behavior
- [ ] Both are red; `BaselineTest` and everything else stays green
- [ ] No production code was modified this stage

## Hand-off

`/hand-off` — cite the new test files as this stage's artifact, and the `mvn test`/`mvn verify`
output confirming the red state.
