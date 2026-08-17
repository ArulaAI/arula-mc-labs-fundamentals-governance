package com.mc.pgs.refunds.api;

import com.mc.pgs.refunds.domain.RefundDecision;
import com.mc.pgs.refunds.domain.RefundPrivilege;
import com.mc.pgs.refunds.domain.RefundRecord;
import com.mc.pgs.refunds.domain.RefundRequest;
import com.mc.pgs.refunds.repo.RefundRecordDao;
import com.mc.pgs.refunds.service.RefundService;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Refund endpoints in the real PGS Payment Processor contract shape
 * ({@code pgs-lab-spec-pack.md}, Spec 1, "API contract"): two endpoints selected by what the
 * caller supplies, not by whether the refund is offline or online. Offline vs. online is a
 * request-body decision -- {@code wsApiSupport.refundAuthorization}, surfaced as
 * {@link RefundRequest#onlineRefundRequested()}.
 *
 * F10 (RISK_REGISTER.md): error handling lives here, locally, rather than in a shared
 * {@code @ControllerAdvice} -- so this endpoint's error shape and Spring Boot's default
 * error shape (for anything this handler doesn't catch) are inconsistent across the service.
 * Backlog, not fixed in this lab.
 *
 * F7: no correlation-id header is read or propagated anywhere below -- also backlog.
 */
@RestController
public class RefundController {

    private static final Logger log = LogManager.getLogger(RefundController.class);

    private final RefundService refundService;
    private final RefundRecordDao refundRecordDao;

    public RefundController(RefundService refundService, RefundRecordDao refundRecordDao) {
        this.refundService = refundService;
        this.refundRecordDao = refundRecordDao;
    }

    /**
     * Caller supplies Order ID + original transaction ID (a PAYMENT refund).
     * {@code POST /card-payments/{card_payment_gateway_id}/refunds}
     */
    @PostMapping("/card-payments/{card_payment_gateway_id}/refunds")
    public ResponseEntity<RefundDecision> refundPayment(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @RequestBody RefundRequest request) {
        return dispatch(request);
    }

    /**
     * Caller supplies payment gateway ID + capture transaction gateway ID (a CAPTURE refund).
     * {@code POST /card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds}
     */
    @PostMapping("/card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds")
    public ResponseEntity<RefundDecision> refundCapture(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @PathVariable("card_transaction_gateway_id") String cardTransactionGatewayId,
            @RequestBody RefundRequest request) {
        return dispatch(request);
    }

    /**
     * Selects the offline or online service path from the request body, per the real contract:
     * both endpoints above accept either kind of refund, and
     * {@code wsApiSupport.refundAuthorization} is what distinguishes them. This is request
     * routing, not business logic -- the rules that decide the outcome stay in RefundService.
     */
    private ResponseEntity<RefundDecision> dispatch(RefundRequest request) {
        return toResponse(request.onlineRefundRequested()
                ? refundService.processOnlineRefund(request)
                : refundService.processOfflineRefund(request));
    }

    /**
     * Infrastructure, not a seeded finding: maps a Declined decision to 409, so a correct F2
     * fix in RefundService (which only needs to start returning Declined -- see
     * FACILITATOR_KEY.md's smallest-diff outline) actually produces the 409 the spec's
     * acceptance criteria require, rather than silently serializing as 200 OK. Scoped to
     * exactly what's tested here -- every Declined this lab currently produces is an
     * idempotency conflict, so a blanket 409 is correct; a service that later declines for a
     * different reason (e.g. a disabled feature toggle) would want a more specific status, but
     * nothing in this lab currently exercises that case.
     */
    private ResponseEntity<RefundDecision> toResponse(RefundDecision decision) {
        if (decision instanceof RefundDecision.Declined) {
            return ResponseEntity.status(409).body(decision);
        }
        return ResponseEntity.ok(decision);
    }

    /**
     * F3 (RISK_REGISTER.md): Void flows are explicitly out of scope
     * (specs/OUT_OF_SCOPE.md) -- this endpoint should not exist at all. Register, do not fix.
     *
     * The path below is a documented lab assumption, not a confirmed contract: the spec pack
     * lists every Void flow as out of scope and therefore never publishes a Void path shape.
     * It follows the {@code /card-payments/{card_payment_gateway_id}/...} convention of the two
     * refund endpoints above so the seeded surface stays internally consistent. See
     * specs/OUT_OF_SCOPE.md.
     *
     * F8 (RISK_REGISTER.md): the privilege check below is business logic that belongs in
     * RefundService, not the controller layer. ArchUnit enforces this -- see
     * ArchitectureIT -- and `mvn verify` will not go green until it's fixed by moving this
     * check into RefundService.
     */
    @PostMapping("/card-payments/{card_payment_gateway_id}/void")
    public ResponseEntity<?> voidRefund(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @RequestBody RefundRequest request) {
        if (request.merchantPrivileges() == null || !request.merchantPrivileges().contains(RefundPrivilege.REFUNDS)) {
            return ResponseEntity.status(403).body(Map.of("error", "Missing REFUNDS privilege"));
        }
        RefundRecord voided = refundRecordDao.markVoided(request.transactionId());
        return ResponseEntity.ok(voided);
    }

    /**
     * F1 (RISK_REGISTER.md), continued: this generic handler returns the raw exception
     * message straight into the response body on every unhandled failure -- an information
     * disclosure path distinct from (and in addition to) RefundService's cleartext
     * authorization-code log and its own request-dump-on-failure log line.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnhandled(Exception ex) {
        log.error("Unhandled error processing refund request", ex);
        return ResponseEntity.status(500).body(Map.of(
                "error", ex.getClass().getSimpleName(),
                "message", ex.getMessage() == null ? "" : ex.getMessage()
        ));
    }
}
