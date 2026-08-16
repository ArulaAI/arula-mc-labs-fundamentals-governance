package com.mc.pgs.refunds.domain;

import java.util.List;

/**
 * Simplified request shape for this lab -- the real PGS API contract (WSAPI -> Payment
 * Processor field mapping, e.g. POST /card-payments/{id}/refunds) is considerably more
 * detailed (see pgs-lab-spec-pack.md). This is a deliberate 120-minute-lab simplification, not
 * the literal production contract -- see specs/refunds-s2i-phase1.spec.md for the note.
 */
public record RefundRequest(
        String transactionId,
        long amountMinor,
        String currency,
        String merchantId,
        String refundReason,
        String idempotencyKey,
        List<RefundPrivilege> merchantPrivileges
) {
}
