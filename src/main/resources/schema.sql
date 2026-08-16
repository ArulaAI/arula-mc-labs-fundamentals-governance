CREATE TABLE IF NOT EXISTS refund_record (
    id                 VARCHAR(64)  PRIMARY KEY,
    transaction_id     VARCHAR(64)  NOT NULL,
    amount_minor       BIGINT       NOT NULL,
    currency           VARCHAR(3)   NOT NULL,
    merchant_id        VARCHAR(64)  NOT NULL,
    idempotency_key    VARCHAR(128),
    status             VARCHAR(32)  NOT NULL,
    authorization_code VARCHAR(64),
    refund_type        VARCHAR(16)  NOT NULL,
    created_at         BIGINT       NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_refund_record_idempotency_key ON refund_record (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_refund_record_transaction_id ON refund_record (transaction_id);
