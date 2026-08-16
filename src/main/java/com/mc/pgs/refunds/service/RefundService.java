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
     */
    public RefundDecision processOfflineRefund(RefundRequest request) {
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
