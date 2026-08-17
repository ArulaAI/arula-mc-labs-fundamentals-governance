# Spec: Support Refunds for S2I transactions, Phase 1

**PGS thread:** `G1190-3291` — Processing domain
**Design docs behind it:** Solution Intent `PG395-I-601`, Boost Modelling Refunds, WIP Refund LLD
**Source of record:** `pgs-lab-spec-pack.md` (Spec 1), sanitised for external sharing

This spec ships complete and pre-authored for Lab 1 — comprehension and judgment against a real
spec, not spec authoring (that's Lab 2).

## Fidelity note — what is real here, and what is still simulated

This lab's endpoints now match the real PGS contract shape:
- `POST /card-payments/{card_payment_gateway_id}/refunds` — refund a PAYMENT
- `POST /card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds` — refund a CAPTURE

Offline vs. online is determined by the request-body field `wsApiSupport.refundAuthorization`, not by URL.

The WSAPI-to-Payment-Processor field mapping is faithful to the contract:

| WSAPI request | Payment Processor request |
|---|---|
| `merchantId` | `merchantWsApiId` |
| `transactionId` | `wsApiSupport.transactionWsApiId` |
| `orderId` | `wsApiSupport.orderWsApiId` |
| `version` | `wsApiSupport.wsApiVersion` |
| `transaction.amount` | `amounts.transactionAmount` |
| `transaction.currency` | `paymentCurrency` |
| `transaction.reference` | `merchantOrder.transactionReference` |
| `transaction.targetTransactionId` | `wsApiSupport.targetTransactionWsApiId` (capture refunds only) |
| `action.refundAuthorization` | `wsApiSupport.refundAuthorization` |

What remains simulated, and what is simply absent:

- **CPC, LCS and DCF are not in this process at all.** The real flow is
  WSAPI → TTA → Payment Processor → CPC → injection → LCS API → DCF; this lab is the Payment
  Processor step only. (The spec pack retains those system names without expanding them, and
  neither does this document — guessing at what the initials stand for would be inventing
  detail the source does not carry.)
- **Settlement is downstream.** The online refund path authorizes; it must not write settlement
  records. DCF / settlement data generation is explicitly out of scope.
- **The H2 in-memory store is a lab fixture**, not a representation of PGS's persistence. It
  uses plain JDBC with explicit SQL and no ORM, which does mirror the real access pattern. That
  it does not survive a restart is a property of the fixture, not a finding — expect it to be
  raised in Stage 1 and correctly rejected.

Assumptions (not yet confirmed against the real contract):
1. The Void endpoint path `POST /card-payments/{card_payment_gateway_id}/void` — the spec pack
   never publishes a Void path because all Void flows are out of scope, so this lab's path follows
   the refund endpoints' convention for internal consistency only.
2. `idempotencyKey` as a top-level request field — the spec pack states the 409 idempotency-conflict
   rule but never names the transport field.

The **business rules and findings below are faithful to the real spec pack**.

## In scope (Phase 1)

- Subsequent offline refund against an existing PAYMENT or CAPTURE, reusing the original source of funds.
- Subsequent online refund (authorization + settlement, gated by `TOGGLE_ENABLE_ONLINE_REFUND`; the
  settlement leg itself is handled downstream, not by this service).
- Full refund for FPAN / MOTO / card-on-file, S2I and S2A.
- Merchant privilege and feature-toggle behaviour (see `RefundPrivilege`), refund linkage to the
  original transaction, reconciliation.

## Out of scope

See `specs/OUT_OF_SCOPE.md`.

## Business rules (testable)

- Only a PAYMENT or CAPTURE may be refunded; a voided transaction cannot be refunded (finding F14).
- Refund amount must not exceed the total captured amount, **unless** the merchant holds the
  `EXCESSIVE_REFUNDS` privilege.
- A retried refund request with the same `idempotencyKey` must return **409** and create no
  second refund record.
- For online refunds, authorization and settlement are two separate stages, gated by
  `TOGGLE_ENABLE_ONLINE_REFUND`.
- **The authorization code must be nulled out of retrieval responses for online refunds**, unless
  the "return refund authorization data to merchants" toggle is explicitly ON
  (`refunds.return-authorization-data-to-merchants` in `application.yml`, default OFF). This is a
  non-negotiable, not a style preference.
- The `REFUND_EXPIRY` privilege exists and gates refund eligibility by a time window. **The window's
  actual value is genuinely not specified anywhere in the spec pack.** This is not an oversight to
  fix — it is finding F5 (see `RISK_REGISTER.md`). The correct response is to register and escalate
  the gap, not invent a default value.
- The merchant must hold the `REFUNDS` privilege to submit a refund; its absence must be rejected
  with 403 (finding F12).
- Refund currency must match the original transaction's currency (finding F13).

## Acceptance criteria

- Given a merchant with the `REFUNDS` privilege and a valid CAPTURE, when a refund is submitted,
  then the refund is processed and an approval is returned.
- Given a merchant without the `REFUNDS` privilege, when a refund is submitted, then the request is
  rejected with 403.
- Given a refund amount above the captured amount, when `EXCESSIVE_REFUNDS` is present, then
  processing continues; when it is absent, then the request is rejected.
- Given `TOGGLE_ENABLE_ONLINE_REFUND` is enabled, when an online refund occurs, then authorization
  and settlement are processed as two separate stages, and the authorization code is nulled from
  the response unless the return-authorization-data toggle is ON.
- Given the same refund request is submitted twice with the same idempotency key, when the second
  arrives, then it returns 409 and no second refund is created.
