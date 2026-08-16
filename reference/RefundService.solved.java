package com.mc.pgs.refunds.service;

// Reference solution -- see reference/README.md. Not compiled as part of the build (this
// package lives outside src/), for the facilitator to point a stuck group at.

import com.mc.pgs.refunds.domain.RefundDecision;
import com.mc.pgs.refunds.domain.RefundPrivilege;
import com.mc.pgs.refunds.domain.RefundRecord;
import com.mc.pgs.refunds.domain.RefundRequest;
import com.mc.pgs.refunds.repo.RefundRecordDao;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.UUID;

@Service
public class RefundService {

    private static final Logger log = LogManager.getLogger(RefundService.class);
    private static final String SETTLEMENT_NOTIFY_URL = "http://settlement-internal.mc-boost.local/notify"; // F9: still backlog, unchanged

    private final RefundRecordDao refundRecordDao;
    private final PreRiskAssessmentClient preRiskAssessmentClient; // F4: still registered, unchanged -- do not remove
    private final boolean onlineRefundEnabled;
    private final boolean returnAuthorizationDataToMerchants;

    public RefundService(
            RefundRecordDao refundRecordDao,
            PreRiskAssessmentClient preRiskAssessmentClient,
            @Value("${refunds.online-refund-enabled:false}") boolean onlineRefundEnabled,
            @Value("${refunds.return-authorization-data-to-merchants:false}") boolean returnAuthorizationDataToMerchants
    ) {
        this.refundRecordDao = refundRecordDao;
        this.preRiskAssessmentClient = preRiskAssessmentClient;
        this.onlineRefundEnabled = onlineRefundEnabled;
        this.returnAuthorizationDataToMerchants = returnAuthorizationDataToMerchants;
    }

    public RefundDecision processOfflineRefund(RefundRequest request) {
        preRiskAssessmentClient.assess(request); // F4: unchanged, registered not fixed

        // F2 FIX: check for an existing record with this idempotencyKey before inserting.
        Optional<RefundRecord> existing = refundRecordDao.findByIdempotencyKey(request.idempotencyKey());
        if (existing.isPresent()) {
            return new RefundDecision.Declined("409 Conflict: refund already processed for this idempotencyKey");
        }

        String authorizationCode = "AUTH-" + UUID.randomUUID();
        RefundRecord record;
        try {
            record = refundRecordDao.insert(new RefundRecord(
                    null, request.transactionId(), request.amountMinor(), request.currency(),
                    request.merchantId(), request.idempotencyKey(), "APPROVED", authorizationCode,
                    "OFFLINE", null
            ));
        } catch (RuntimeException ex) {
            // F1 FIX: log the failure context WITHOUT the authorization code.
            log.error("Failed to process offline refund for transactionId={}", request.transactionId(), ex);
            throw ex;
        }

        // F1 FIX: no authorization code in the log line.
        log.info("Processed offline refund: transactionId={}, status=APPROVED", record.transactionId());

        return new RefundDecision.Approved(record.transactionId(), record.amountMinor(), record.authorizationCode());
    }

    /** Stage 4 build target, now implemented. */
    public RefundDecision processOnlineRefund(RefundRequest request) {
        if (!onlineRefundEnabled) {
            return new RefundDecision.Declined("Online refunds are not enabled (TOGGLE_ENABLE_ONLINE_REFUND is off)");
        }

        Optional<RefundRecord> existing = refundRecordDao.findByIdempotencyKey(request.idempotencyKey());
        if (existing.isPresent()) {
            return new RefundDecision.Declined("409 Conflict: refund already processed for this idempotencyKey");
        }

        preRiskAssessmentClient.assess(request); // F4: unchanged, registered not fixed

        String authorizationCode = "AUTH-" + UUID.randomUUID();
        RefundRecord record = refundRecordDao.insert(new RefundRecord(
                null, request.transactionId(), request.amountMinor(), request.currency(),
                request.merchantId(), request.idempotencyKey(), "APPROVED", authorizationCode,
                "ONLINE", null
        ));
        log.info("Processed online refund: transactionId={}, status=APPROVED", record.transactionId());

        // Non-negotiable: null the authorization code from retrieval unless the toggle is ON.
        // Settlement records are NOT written here -- DCF/settlement is downstream, out of scope.
        String returnedAuthCode = returnAuthorizationDataToMerchants ? record.authorizationCode() : null;
        return new RefundDecision.Approved(record.transactionId(), record.amountMinor(), returnedAuthCode);
    }

    /** F8 FIX target: privilege check + DAO access, moved here from RefundController. */
    public RefundRecord voidRefund(RefundRequest request) {
        if (request.merchantPrivileges() == null || !request.merchantPrivileges().contains(RefundPrivilege.REFUNDS)) {
            throw new IllegalStateException("Missing REFUNDS privilege"); // mapped to 403 by the controller
        }
        return refundRecordDao.markVoided(request.transactionId());
        // F3: this method existing at all is still the registered finding -- unchanged, not fixed.
    }
}
