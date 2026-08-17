package com.mc.pgs.refunds.api;

// Reference solution -- see reference/README.md. Not compiled as part of the build.

import com.mc.pgs.refunds.domain.RefundDecision;
import com.mc.pgs.refunds.domain.RefundRequest;
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
 * F8 FIX: no RefundRecordDao field anymore -- the controller only talks to RefundService.
 * This is what makes ArchitectureIT (no ..api.. depends on ..repo..) go green.
 *
 * F10, F7, F11: still unchanged/backlog, as intended -- no @ControllerAdvice, no correlation
 * id, and RefundHealthIndicator still reports UP without checking anything.
 */
@RestController
public class RefundController {

    private static final Logger log = LogManager.getLogger(RefundController.class);

    private final RefundService refundService;

    public RefundController(RefundService refundService) {
        this.refundService = refundService;
    }

    /** Caller supplies Order ID + original transaction ID (a PAYMENT refund). Unchanged by
     * any Stage 4 fix -- the endpoint shape is the seeded contract, not a finding. */
    @PostMapping("/card-payments/{card_payment_gateway_id}/refunds")
    public ResponseEntity<RefundDecision> refundPayment(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @RequestBody RefundRequest request) {
        return dispatch(request);
    }

    /** Caller supplies payment gateway ID + capture transaction gateway ID (a CAPTURE refund). */
    @PostMapping("/card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds")
    public ResponseEntity<RefundDecision> refundCapture(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @PathVariable("card_transaction_gateway_id") String cardTransactionGatewayId,
            @RequestBody RefundRequest request) {
        return dispatch(request);
    }

    /** Offline vs. online comes from wsApiSupport.refundAuthorization in the body, not the URL. */
    private ResponseEntity<RefundDecision> dispatch(RefundRequest request) {
        return toResponse(request.onlineRefundRequested()
                ? refundService.processOnlineRefund(request)
                : refundService.processOfflineRefund(request));
    }

    /** Maps Declined -> 409, same as the seeded starting controller (this is infrastructure
     * already present pre-fix, not something F2's remediation needs to add). */
    private ResponseEntity<RefundDecision> toResponse(RefundDecision decision) {
        if (decision instanceof RefundDecision.Declined) {
            return ResponseEntity.status(409).body(decision);
        }
        return ResponseEntity.ok(decision);
    }

    /** F3: still registered, unchanged -- this endpoint answering at all remains the finding.
     * The path is a documented lab assumption (the spec pack never publishes a Void path,
     * because every Void flow is out of scope) -- see specs/OUT_OF_SCOPE.md. */
    @PostMapping("/card-payments/{card_payment_gateway_id}/void")
    public ResponseEntity<?> voidRefund(
            @PathVariable("card_payment_gateway_id") String cardPaymentGatewayId,
            @RequestBody RefundRequest request) {
        try {
            return ResponseEntity.ok(refundService.voidRefund(request));
        } catch (IllegalStateException ex) {
            return ResponseEntity.status(403).body(Map.of("error", ex.getMessage()));
        }
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnhandled(Exception ex) {
        log.error("Unhandled error processing refund request", ex);
        return ResponseEntity.status(500).body(Map.of(
                "error", ex.getClass().getSimpleName(),
                "message", ex.getMessage() == null ? "" : ex.getMessage()
        ));
    }
}
