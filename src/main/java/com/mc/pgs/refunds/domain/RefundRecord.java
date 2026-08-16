package com.mc.pgs.refunds.domain;

import java.time.Instant;

/**
 * A persisted refund row, as stored by RefundRecordDao. Deliberately carries
 * {@code authorizationCode} in cleartext at the domain-object level -- masking/nulling
 * decisions belong at the boundary (logging, response serialization), not by omitting the
 * field from the record itself. See RISK_REGISTER.md finding F1.
 */
public record RefundRecord(
        String id,
        String transactionId,
        long amountMinor,
        String currency,
        String merchantId,
        String idempotencyKey,
        String status,
        String authorizationCode,
        String refundType,
        Instant createdAt
) {
}
