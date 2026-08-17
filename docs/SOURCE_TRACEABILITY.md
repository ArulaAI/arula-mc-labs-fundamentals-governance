# Source traceability — where every design decision in this lab came from

**Not participant-facing.** This is the provenance record for the lab's own construction: for
each decision baked into the seeded code, the specs, and the governance wiring, which source it
came from and how much authority that source carries.

It exists because "is this real, or did we make it up?" is the single most common question this
lab attracts — from SMEs reviewing it, from facilitators asked it live by a participant, and
from whoever picks this repo up next. Answering it from memory does not scale, and answering it
wrong once costs the lab its credibility with a payments audience.

## Source precedence

When two sources disagree, the higher row wins. Anything not traceable to rows 1-3 is a lab
fixture decision and must be labelled as one, in the artifact itself, not only here.

| # | Source | Authority | What it governs |
|---|---|---|---|
| 1 | `pgs-lab-spec-pack.md` (Spec 1 — Support Refunds for S2I transactions) | **Authoritative.** Taken from PGS's Confluence Modelling / LLD / service-reference pages, sanitised for external sharing | API contract, request/response field mapping, HTTP status codes, merchant privileges, business rules, error scenarios, acceptance criteria, and the planted wrinkles the findings are built from |
| 2 | `pgs-epic-feature-story-examples.md` | **Authoritative** for backlog framing | Thread `G1190-3291`, the epic/feature/story shape, the Processing-domain context |
| 3 | `pgs-example-claude-md-for-labs.md` | **Authoritative** for house style | What a PGS-shaped `CLAUDE.md`/`AGENTS.md` looks like; the rules-and-agents idiom this repo follows |
| 4 | Lab fixture decision | **Ours.** Must be labelled as an assumption wherever it appears | Anything invented to make a 120-minute lab work: the H2 store, the seeded finding *placement*, the Void path shape, the idempotency transport field |

## Decision provenance

### Endpoints and request shape

| Decision | Source | Note |
|---|---|---|
| `POST /card-payments/{card_payment_gateway_id}/refunds` | 1 | Verbatim from the spec pack's "API contract" table — the caller supplies Order ID + original transaction ID |
| `POST /card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds` | 1 | Verbatim, same table — the caller supplies payment gateway ID + capture transaction gateway ID |
| Offline vs. online selected by `wsApiSupport.refundAuthorization` in the body, not by the URL | 1 | The spec pack's field-mapping table annotates `action.refundAuthorization` -> `wsApiSupport.refundAuthorization` with "Governs online vs offline behaviour" |
| `refundAuthorization` ignored when the merchant holds `ENFORCE_REFUNDS_WITHOUT_AUTHORIZATIONS` | 1 | Spec pack business rules, stated directly. Implemented in `RefundRequest.onlineRefundRequested()` |
| Nested request shape (`amounts`, `merchantOrder`, `wsApiSupport`) and every field name in it | 1 | One-for-one with the spec pack's WSAPI -> Payment Processor mapping table |
| `idempotencyKey` as a top-level request field | **4 — ASSUMPTION** | The spec pack states the 409 idempotency-conflict rule in both its business rules and its error table, but never names the transport field. Labelled as assumed in `RefundRequest`'s javadoc and in `specs/refunds-s2i-phase1.spec.md` |
| `POST /card-payments/{card_payment_gateway_id}/void` | **4 — ASSUMPTION** | No real shape exists in any source material, and none can: every Void flow is out of scope, so the spec pack never publishes a Void path. This follows the refund endpoints' convention purely for internal consistency. Labelled as assumed in `RefundController`, `specs/OUT_OF_SCOPE.md` and `specs/refunds-s2i-phase1.spec.md` |
| 200 / 400 / 403 / 405 / 409 / 500 status semantics | 1 | Spec pack's HTTP status-code table |

### Business rules and privileges

| Decision | Source | Note |
|---|---|---|
| All six `RefundPrivilege` values | 1 | Spec pack's merchant-privilege table, complete |
| `REFUND_EXPIRY`'s window value left undefined | 1 | **This is a genuine silence in the source, not an omission of ours.** The spec pack names the privilege and its purpose and never states a duration. That silence is finding F5, and inventing a value here would destroy the lab's central lesson |
| 409 + no second record on a repeated idempotency key | 1 | Business rules and acceptance criteria, both |
| Auth code nulled from **online** refund retrieval unless the return-authorization-data toggle is ON | 1 | Spec pack, stated as a non-negotiable. Scoped to online retrieval — the offline response is not covered, which is why F1 is logs-only on the offline path |
| Settlement leg handled downstream, not written by this service | 1 | Spec pack out-of-scope list: DCF / settlement data generation |
| No pre-risk assessment on subsequent refunds | 1 | Spec pack out-of-scope list, stated explicitly. Finding F4 is the deliberate violation of it |
| `refunds.return-authorization-data-to-merchants` as the toggle's config key | **4 — fixture** | The spec pack names the toggle in prose ("return refund authorization data to merchants") but not as a config key. The key name is ours |
| `TOGGLE_ENABLE_ONLINE_REFUND` -> `refunds.online-refund-enabled` | 1 for the toggle, **4** for the config key | Same reasoning as the row above |

### Seeded findings

Every finding traces to a spec-pack statement. The *placement* — which class, which method — is
a fixture decision in each case, chosen so the finding is discoverable in a 25-minute Stage 1.

| Finding | Source of the rule it violates | Note |
|---|---|---|
| F1 — authorization code and full request logged | 1 | Spec pack's planted wrinkles: "An agent that logs the full response or returns the auth code by default leaks it. Non-negotiable." The *log* sink is our placement; the sensitivity of the field is theirs |
| F2 — no idempotency | 1 | Planted wrinkles: "the 409 idempotency conflict is easy to drop" |
| F3 — Void endpoint answering at all | 1 | Planted wrinkles: "the out-of-scope list explicitly excludes all Void flows" |
| F4 — hallucinated `PreRiskAssessmentClient` | 1 | Planted wrinkles: "there is no pre-risk assessment on subsequent refunds" |
| F5 — `REFUND_EXPIRY` window undefined | 1 | The source's silence, preserved deliberately. The most authentic finding in the lab and the only one that could not have been invented |
| F6 — no `EXCESSIVE_REFUNDS` gate | 1 | Planted wrinkles: "an agent that lets a refund exceed the captured amount without checking `EXCESSIVE_REFUNDS`" |
| F7 — no correlation ID | 1 (Spec 2) | Spec 2's tracing/correlation header list establishes that correlation propagation is a real platform expectation. Hygiene-tier, backlog |
| F8 — controller reaches into the repo layer | **4 — fixture** | Not a spec finding. It exists to be caught *mechanically* by ArchUnit, which is the teaching point: some findings should be caught by the build, not by eye |
| F9 — hardcoded settlement-notify URL | **4 — fixture** | Hygiene finding. The settlement leg itself is source 1 (out of scope, downstream); the hardcoded literal is ours |
| F10 — no `@ControllerAdvice` | **4 — fixture** | Hygiene finding, Spring-idiom rather than spec |
| F11 — always-UP health indicator | **4 — fixture** | Hygiene finding. Nothing in the spec pack covers health endpoints; this is a general operability concern, deliberately seeded as an easy find |
| F12 — no `REFUNDS` privilege gate on the base path | 1 | Spec pack: "`REFUNDS` — required for all refunds", and the error table's "Missing `REFUNDS` privilege -> Rejected (403)". Distinct from F6 |
| F13 — no currency-match validation | 1 | Spec pack business rules: "Currency must equal the original order currency"; error table: "Currency mismatch -> Rejected" |
| F14 — no voided-target rejection | 1 | Spec pack business rules: "**Voided transactions cannot be refunded**"; error table: "Target transaction voided -> Rejected" |
| F15 — no positive-input validation | 1, and `pgs-example-claude-md-for-labs.md` | Spec pack business rules: "amount must be positive and a valid ISO currency"; also stated as a hard non-negotiable in Mastercard's own Eng Std 5.1-5.3 ("positive input validation... deny-lists are not acceptable"), not just this feature's spec |
| F16 — dead-weight privileges (`ENABLE_REFUND_REQUESTS`, `SUPPORT_EXTENDED_REFUNDS`) | 1 | Both privileges are named in the spec pack's own privilege table; neither is enforced anywhere in this service. Added on a later hardening pass after a direct audit found the enum values had zero usages and zero registered findings pointing at them |

**A source ambiguity, not silently resolved:** the spec pack's "Out of scope (Phase 1)" list
states "Excessive refund is Phase 1.1" — placing `EXCESSIVE_REFUNDS` gating (F6) explicitly
*outside* Phase 1. But the same document's Business Rules, Error Scenarios and Acceptance
Criteria sections all describe that exact gating as active, testable Phase 1 behavior, with its
own Given/When/Then AC. `pgs-epic-feature-story-examples.md`'s phasing note repeats "Phase 1.1
excessive refund" independently, so this is not a one-off typo in a single document. F6 is kept
as a registered finding here because the spec pack's own ACs describe it as testable, not
because the phasing question has been resolved — it hasn't. This is source material Mastercard
should be asked to clarify, not something this lab's construction should have silently picked a
side on.

**Known simplifications, stated plainly rather than silently absent (added on a later hardening
pass, deliberately not fixed before a live cohort run):**
- The **response** shape (`RefundDecision`) stays flat (`transactionId`/`amountMinor`/
  `authorizationCode`), not the spec pack's full nested contract (`order.totalCapturedAmount`,
  `order.status`, `transaction.authorizationResponse.*`, processed-card blocks). The
  **request** shape was fully migrated to the real nested contract; the response was not, in the
  same pass, which is an asymmetry worth being honest about rather than presenting as complete.
  Not fixed now because changing the wire response shape ripples through every test, exercise
  and reference solution that consumes it — real risk for a change this close to a cohort
  session, for a fidelity gain with no functional impact on the lab's teaching goals.
- **No OpenAPI contract file.** Both `pgs-epic-feature-story-examples.md` and
  `pgs-example-claude-md-for-labs.md` state "OpenAPI-first: define the contract before
  implementing" as a standard. This lab uses a markdown spec (`specs/refunds-s2i-phase1.spec.md`)
  instead. A real gap relative to the stated standard, not something this lab uniquely
  introduced.
- **No PITest (mutation testing) in this lab**, despite it being named in Mastercard's own stack
  and non-negotiables list. Deliberate sequencing, not an oversight: mutation testing is Lab 3's
  teaching moment in this series, not Lab 1's.

### Governance and grading infrastructure

| Decision | Source | Note |
|---|---|---|
| `workbench` plugin supplies rules, agents, commands, journey recording, quality gates | 3 + the plugin's own docs | The repo consumes the plugin rather than vendoring it |
| `.claude/hooks/gate_guard.py` shipped repo-locally | **4 — deliberate exception** | The plugin ships no blocking hook; `quality_gates.py` reports only. Without a local one, `reference/` is not actually gated during a live session. Documented as an exception in `AGENTS.md`, `README.md` and `tests/test_repo_structure.sh` |
| `.claude/scripts/grade_repo.py` shipped repo-locally | **4 — stopgap** | The plugin's grader does not implement the content checks this rubric needs. Same rubric file, same results, no plugin required |
| `.claude/scripts/anti_gaming_check.py` | **4 — ours** | Mutation-style check with no counterpart in any source. Closes a gap no content check can: whether the participant's F1 test detects anything |
| `seed_intact:` / F5 byte-for-byte grading | **4 — ours** | Added because a register row alone cannot distinguish "escalated the gap" from "invented a value and also wrote a nice row" |
| ArchUnit as a build-blocking gate | **4 — fixture** | Pedagogical: one finding must be caught by the build rather than by reading |
| Stack version pins in `pom.xml` | **3 — sourced, mostly confirmed** | Spring Boot 3.5.14, Log4j2 2.25.4, ArchUnit 1.2.1 match `pgs-example-claude-md-for-labs.md`'s "Our stack" section exactly (`pgs-lab-spec-pack.md` alone is silent on tooling, which is why this was previously called unconfirmed — the other source was never checked). One real gap: JaCoCo runs standalone where the real stack names SonarQube for coverage. See `pom.xml`'s own comment |
| Java 17 language level on a Zulu 21 JDK | **4 — lab stack** | Consistent across `pom.xml`, `README.md` and `AGENTS.md`. Not a discrepancy: 17 is the language level, 21 is the runtime |
| H2 in-memory store, plain JDBC | **4 — fixture** | Chosen to mirror PGS's no-ORM access pattern without needing a database on a lab machine. A seeded decoy in Stage 1 depends on participants correctly rejecting "this won't survive a restart" as a finding |

## Maintaining this file

Add a row when a decision is made, not afterwards. A decision that reaches the repo without a
row here becomes indistinguishable from a spec-derived one within a week — which is exactly the
confusion this file exists to prevent. If a row's source is 4, the artifact itself must also say
so; this file is the index, not the disclosure.
