# Out of scope — Refunds for S2I, Phase 1

Explicit and unambiguous, per `pgs-lab-spec-pack.md`, Spec 1:

- **Unsettled transactions.**
- **All Void flows** (Void-Auth, Void-Capture, Void-Pay, Void-Refund). `POST /void-refunds`
  answering at all is finding F3 — register it, do not build it out further.
- **Pre-settlement reversals.**
- **Non-card refunds.**
- **DCF / settlement data generation** — handled downstream, not by this service. The online
  refund path authorizes; it must not write settlement records.
- Excessive refund handling beyond the `EXCESSIVE_REFUNDS` privilege check is **Phase 1.1**;
  partial refund, scheme-token, and device-payment cases are **Phase 2**.
- **There is no pre-risk assessment for subsequent refund transactions.** Any call to a
  pre-risk/fraud service on this path is a hallucinated dependency (finding F4).

Hold this line during Stage 4 — if Claude Code offers to build any of the above while
implementing `processOnlineRefund()`, decline it and note it, don't build it.
