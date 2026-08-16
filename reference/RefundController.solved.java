package com.mc.pgs.refunds.api;

// Reference solution -- see reference/README.md. Not compiled as part of the build.

import com.mc.pgs.refunds.domain.RefundDecision;
import com.mc.pgs.refunds.domain.RefundRequest;
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
 * F8 FIX: no RefundRecordDao field anymore -- the controller only talks to RefundService.
 * This is what makes ArchitectureIT (no ..api.. depends on ..repo..) go green.
 *
 * F10, F7: still unchanged/backlog, as intended -- no @ControllerAdvice, no correlation id.
 */
@RestController
public class RefundController {

    private static final Logger log = LogManager.getLogger(RefundController.class);

    private final RefundService refundService;

    public RefundController(RefundService refundService) {
        this.refundService = refundService;
    }

    @PostMapping("/refunds/offline")
    public ResponseEntity<RefundDecision> refundOffline(@RequestBody RefundRequest request) {
        return toResponse(refundService.processOfflineRefund(request));
    }

    @PostMapping("/refunds/online")
    public ResponseEntity<RefundDecision> refundOnline(@RequestBody RefundRequest request) {
        return toResponse(refundService.processOnlineRefund(request));
    }

    /** Maps Declined -> 409, same as the seeded starting controller (this is infrastructure
     * already present pre-fix, not something F2's remediation needs to add). */
    private ResponseEntity<RefundDecision> toResponse(RefundDecision decision) {
        if (decision instanceof RefundDecision.Declined) {
            return ResponseEntity.status(409).body(decision);
        }
        return ResponseEntity.ok(decision);
    }

    /** F3: still registered, unchanged -- this endpoint answering at all remains the finding. */
    @PostMapping("/void-refunds")
    public ResponseEntity<?> voidRefund(@RequestBody RefundRequest request) {
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
