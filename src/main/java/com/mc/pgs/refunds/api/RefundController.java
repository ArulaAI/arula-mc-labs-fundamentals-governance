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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
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

    @PostMapping("/refunds/offline")
    public ResponseEntity<RefundDecision> refundOffline(@RequestBody RefundRequest request) {
        return toResponse(refundService.processOfflineRefund(request));
    }

    @PostMapping("/refunds/online")
    public ResponseEntity<RefundDecision> refundOnline(@RequestBody RefundRequest request) {
        return toResponse(refundService.processOnlineRefund(request));
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
     * F8 (RISK_REGISTER.md): the privilege check below is business logic that belongs in
     * RefundService, not the controller layer. ArchUnit enforces this -- see
     * ArchitectureTest -- and `mvn verify` will not go green until it's fixed by moving this
     * check into RefundService.
     */
    @PostMapping("/void-refunds")
    public ResponseEntity<?> voidRefund(@RequestBody RefundRequest request) {
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
