package com.mc.pgs.refunds.repo;

import com.mc.pgs.refunds.domain.RefundRecord;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Plain JDBC against H2 (JdbcTemplate, explicit SQL) -- no ORM, no entity mapping, mirroring
 * PGS's real access pattern per the Lab 1 build spec.
 */
@Repository
public class RefundRecordDao {

    private final JdbcTemplate jdbc;

    public RefundRecordDao(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public RefundRecord insert(RefundRecord record) {
        String id = record.id() != null ? record.id() : UUID.randomUUID().toString();
        Instant createdAt = record.createdAt() != null ? record.createdAt() : Instant.now();
        jdbc.update(
                "INSERT INTO refund_record " +
                        "(id, transaction_id, amount_minor, currency, merchant_id, idempotency_key, " +
                        " status, authorization_code, refund_type, created_at) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                id, record.transactionId(), record.amountMinor(), record.currency(), record.merchantId(),
                record.idempotencyKey(), record.status(), record.authorizationCode(), record.refundType(),
                createdAt.toEpochMilli()
        );
        return new RefundRecord(id, record.transactionId(), record.amountMinor(), record.currency(),
                record.merchantId(), record.idempotencyKey(), record.status(), record.authorizationCode(),
                record.refundType(), createdAt);
    }

    /**
     * F2 (RISK_REGISTER.md): nothing in RefundService calls this before inserting, so a
     * retried request with the same idempotencyKey creates a second row instead of returning
     * 409. The method exists so the Stage-4 fix can wire it in without adding new DAO surface.
     */
    public Optional<RefundRecord> findByIdempotencyKey(String idempotencyKey) {
        List<RefundRecord> rows = jdbc.query(
                "SELECT * FROM refund_record WHERE idempotency_key = ?",
                this::mapRow, idempotencyKey
        );
        return rows.stream().findFirst();
    }

    public List<RefundRecord> findByTransactionId(String transactionId) {
        return jdbc.query("SELECT * FROM refund_record WHERE transaction_id = ?", this::mapRow, transactionId);
    }

    public RefundRecord markVoided(String transactionId) {
        jdbc.update("UPDATE refund_record SET status = 'VOIDED' WHERE transaction_id = ?", transactionId);
        return findByTransactionId(transactionId).stream().findFirst()
                .orElseThrow(() -> new IllegalArgumentException("No refund record for transaction " + transactionId));
    }

    private RefundRecord mapRow(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
        return new RefundRecord(
                rs.getString("id"),
                rs.getString("transaction_id"),
                rs.getLong("amount_minor"),
                rs.getString("currency"),
                rs.getString("merchant_id"),
                rs.getString("idempotency_key"),
                rs.getString("status"),
                rs.getString("authorization_code"),
                rs.getString("refund_type"),
                Instant.ofEpochMilli(rs.getLong("created_at"))
        );
    }
}
