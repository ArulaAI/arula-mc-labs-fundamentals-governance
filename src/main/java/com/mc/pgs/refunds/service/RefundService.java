package com.mc.pgs.refunds.service;

import com.mc.pgs.refunds.domain.RefundDecision;
import com.mc.pgs.refunds.domain.RefundRecord;
import com.mc.pgs.refunds.domain.RefundRequest;
import com.mc.pgs.refunds.repo.RefundRecordDao;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class RefundService {

    private static final Logger log = LogManager.getLogger(RefundService.class);

    /**
     * F9 (RISK_REGISTER.md): downstream settlement-notify endpoint, hardcoded rather than
     * externalised to application.yml. Never actually called -- settlement/DCF is downstream
     * and out of scope (specs/OUT_OF_SCOPE.md) -- but the hardcoded literal is itself the
     * finding. Backlog, not fixed in this lab.
     */
    private static final String SETTLEMENT_NOTIFY_URL = "http://settlement-internal.mc-boost.local/notify";

    private final RefundRecordDao refundRecordDao;
    private final PreRiskAssessmentClient preRiskAssessmentClient;

    public RefundService(RefundRecordDao refundRecordDao, PreRiskAssessmentClient preRiskAssessmentClient) {
        this.refundRecordDao = refundRecordDao;
        this.preRiskAssessmentClient = preRiskAssessmentClient;
    }

    /**
     * Offline refund path -- already built, tests green, per the sprint handoff scenario.
     * Two findings are seeded in this method on purpose (see RISK_REGISTER.md):
     *
     * F1 -- the authorization code is logged in cleartext at INFO below. F4 -- the call to
     * preRiskAssessmentClient below is a hallucinated dependency; the spec has no such step.
     *
     * Four further findings are seeded here by omission rather than by wrong code -- F12, F13,
     * F14 and F15 (see RISK_REGISTER.md). Each is a business rule the spec pack states plainly
     * and this method simply never implements. All four are backlog: register them, do not fix
     * them in this lab.
     */
    public RefundDecision processOfflineRefund(RefundRequest request) {
        // F12: no REFUNDS privilege gate. The spec pack's error table is explicit -- "Missing
        // REFUNDS privilege -> Rejected (403)" -- and REFUNDS is "required for all refunds".
        // This method never inspects request.merchantPrivileges() at all, so a merchant with no
        // privileges gets a refund processed. Distinct from F6, which is specifically about the
        // EXCESSIVE_REFUNDS gate on the above-captured-amount path.
        //
        // F13: no currency-match validation. The spec pack requires the refund currency to
        // equal the original order currency ("Currency mismatch -> Rejected"). The inbound
        // paymentCurrency is written straight to the record below, never compared to anything.
        //
        // F14: no voided-target rejection. "Voided transactions cannot be refunded" and
        // "Target transaction voided -> Rejected". Nothing here looks up the target
        // transaction's status, so a VOIDED record can be refunded.
        //
        // F15: no positive-input validation at all. The spec pack's own business rules require
        // "amount must be positive and a valid ISO currency" -- and Mastercard's Eng Std 5.1-5.3
        // (pgs-example-claude-md-for-labs.md, "Trust boundaries and input handling") name
        // positive input validation as a non-negotiable, not an optional nicety. Nothing in this
        // method checks amountMinor > 0 or that currency is a real ISO-4217 code before it's
        // written to the record below. Distinct from F13 (currency MATCHES the original order)
        // -- this is currency/amount being well-formed at all, checked or not.

        // F4: no pre-risk-assessment step exists in the spec for subsequent refunds.
        preRiskAssessmentClient.assess(request);

        // F2: no idempotency check. A retried request with the same idempotencyKey should
        // return 409 and create no second record -- instead it always inserts a fresh row.
        String authorizationCode = "AUTH-" + UUID.randomUUID();
        RefundRecord record;
        try {
            record = refundRecordDao.insert(new RefundRecord(
                    null,
                    request.transactionId(),
                    request.amountMinor(),
                    request.currency(),
                    request.merchantId(),
                    request.idempotencyKey(),
                    "APPROVED",
                    authorizationCode,
                    "OFFLINE",
                    null
            ));
        } catch (RuntimeException ex) {
            // F1: the full inbound request is logged here on failure -- this is the
            // "full request object logged" half of F1, distinct from the authorization-code
            // log below.
            log.error("Failed to process offline refund for request={}", request, ex);
            throw ex;
        }

        // F1: full refund record -- including the authorization code -- logged at INFO.
        log.info("Processed offline refund: {}", record);

        return new RefundDecision.Approved(record.transactionId(), record.amountMinor(), record.authorizationCode());
    }

    /**
     * Online refund path -- not yet built. This is the sprint's actual task: honour
     * TOGGLE_ENABLE_ONLINE_REFUND, null the authorization code from any retrieved record
     * unless the "return refund authorization data to merchants" toggle is ON, and do not
     * write settlement records (DCF/settlement is downstream, out of scope).
     */
    public RefundDecision processOnlineRefund(RefundRequest request) {
        throw new UnsupportedOperationException("Online refund path not yet implemented");
    }
}
