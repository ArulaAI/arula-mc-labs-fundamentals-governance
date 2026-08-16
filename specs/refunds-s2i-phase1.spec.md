# Spec: Support Refunds for S2I transactions, Phase 1

**PGS thread:** `G1190-3291` — Processing domain
**Design docs behind it:** Solution Intent `PG395-I-601`, Boost Modelling Refunds, WIP Refund LLD
**Source of record:** `pgs-lab-spec-pack.md` (Spec 1), sanitised for external sharing

This spec ships complete and pre-authored for Lab 1 — comprehension and judgment against a real
spec, not spec authoring (that's Lab 2).

## Fidelity note — read before assuming this is the literal production contract

This lab's `RefundController` uses a simplified endpoint shape (`POST /refunds/offline`,
`POST /refunds/online`) and a simplified request record, not the real PGS API contract. The real
contract is considerably more detailed: two endpoints on the Payment Processor selected by what
the caller supplies (`POST /card-payments/{card_payment_gateway_id}/refunds` and
`POST /card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds`),
with a full WSAPI-to-Payment-Processor field mapping (`merchantId`→`merchantWsApiId`,
`transactionId`→`wsApiSupport.transactionWsApiId`, etc.). This simplification is a deliberate
120-minute-lab choice, made explicitly and not silently — don't mistake the seeded code below for
the literal production API surface.

The **business rules and findings below are faithful to the real spec pack**, even though the
endpoint shapes are simplified.

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

- Only a PAYMENT or CAPTURE may be refunded; a voided transaction cannot be refunded.
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
