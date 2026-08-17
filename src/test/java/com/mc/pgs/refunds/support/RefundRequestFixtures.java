package com.mc.pgs.refunds.support;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mc.pgs.refunds.domain.RefundPrivilege;
import com.mc.pgs.refunds.domain.RefundRequest;

import java.util.ArrayList;
import java.util.List;

/**
 * Test-fixture builder for {@link RefundRequest}.
 *
 * <p>The request shape is faithful to the real PGS Payment Processor contract, which means it
 * is nested ({@code amounts}, {@code merchantOrder}, {@code wsApiSupport}). Assembling that by
 * hand in every test -- or worse, hand-writing the equivalent JSON string into a MockMvc call
 * -- is busywork that has nothing to do with what Stage 3 is actually teaching. Use this
 * instead.
 *
 * <pre>{@code
 * // an offline refund, sensible defaults for everything you don't care about
 * RefundRequest req = RefundRequestFixtures.offlineRefund().build();
 *
 * // the same refund submitted twice -- the F2 idempotency case
 * RefundRequest first  = RefundRequestFixtures.offlineRefund().idempotencyKey("idem-1").build();
 * RefundRequest retry  = RefundRequestFixtures.offlineRefund().idempotencyKey("idem-1").build();
 *
 * // an online refund (wsApiSupport.refundAuthorization = true)
 * RefundRequest online = RefundRequestFixtures.onlineRefund().build();
 *
 * // the JSON body for a MockMvc post, already in the nested contract shape
 * String body = RefundRequestFixtures.offlineRefund().json();
 * }</pre>
 *
 * <p>Every value below is synthetic. There is no real cardholder data anywhere in this lab and
 * none should be introduced here -- see the {@code payments-guardrails} rule.
 */
public final class RefundRequestFixtures {

    /** Path of the PAYMENT-refund endpoint, ready to hand to MockMvc. */
    public static final String PAYMENT_REFUND_PATH = "/card-payments/cpg-1001/refunds";

    /** Path of the CAPTURE-refund endpoint, ready to hand to MockMvc. */
    public static final String CAPTURE_REFUND_PATH = "/card-payments/cpg-1001/card-captures/ctg-2002/refunds";

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private RefundRequestFixtures() {
    }

    /** A valid OFFLINE refund: {@code wsApiSupport.refundAuthorization} absent. */
    public static Builder offlineRefund() {
        return new Builder().online(false);
    }

    /** A valid ONLINE refund: {@code wsApiSupport.refundAuthorization = true}. */
    public static Builder onlineRefund() {
        return new Builder().online(true);
    }

    /** Mutable builder -- defaults are valid, override only what your test is about. */
    public static final class Builder {

        private String merchantWsApiId = "merchant-0001";
        private String paymentCurrency = "USD";
        private long transactionAmount = 2500L;
        private String transactionReference = "ref-0001";
        private String transactionWsApiId = "txn-0001";
        private String orderWsApiId = "order-0001";
        private String wsApiVersion = "1.0";
        private String targetTransactionWsApiId = null;
        private Boolean refundAuthorization = null;
        private String idempotencyKey = "idem-0001";
        private final List<RefundPrivilege> merchantPrivileges =
                new ArrayList<>(List.of(RefundPrivilege.REFUNDS));

        /** {@code merchantWsApiId} (WSAPI {@code merchantId}). */
        public Builder merchantId(String value) {
            this.merchantWsApiId = value;
            return this;
        }

        /** {@code paymentCurrency} (WSAPI {@code transaction.currency}). */
        public Builder currency(String value) {
            this.paymentCurrency = value;
            return this;
        }

        /** {@code amounts.transactionAmount}, in minor units. */
        public Builder amountMinor(long value) {
            this.transactionAmount = value;
            return this;
        }

        /** {@code merchantOrder.transactionReference}. */
        public Builder transactionReference(String value) {
            this.transactionReference = value;
            return this;
        }

        /** {@code wsApiSupport.transactionWsApiId} (WSAPI {@code transactionId}). */
        public Builder transactionId(String value) {
            this.transactionWsApiId = value;
            return this;
        }

        /** {@code wsApiSupport.orderWsApiId} (WSAPI {@code orderId}). */
        public Builder orderId(String value) {
            this.orderWsApiId = value;
            return this;
        }

        /** {@code wsApiSupport.targetTransactionWsApiId} -- capture refunds only. */
        public Builder targetTransactionId(String value) {
            this.targetTransactionWsApiId = value;
            return this;
        }

        /** Idempotency key. Two requests sharing one key are the F2 retry case. */
        public Builder idempotencyKey(String value) {
            this.idempotencyKey = value;
            return this;
        }

        /**
         * Sets {@code wsApiSupport.refundAuthorization}, which is what selects the online path
         * -- see {@link RefundRequest#onlineRefundRequested()}.
         */
        public Builder online(boolean value) {
            this.refundAuthorization = value ? Boolean.TRUE : null;
            return this;
        }

        /** Replaces the privilege list wholesale (default: {@code REFUNDS} only). */
        public Builder privileges(RefundPrivilege... values) {
            this.merchantPrivileges.clear();
            this.merchantPrivileges.addAll(List.of(values));
            return this;
        }

        /** Adds one privilege on top of whatever is already set. */
        public Builder withPrivilege(RefundPrivilege value) {
            this.merchantPrivileges.add(value);
            return this;
        }

        /** Removes every privilege -- the "missing REFUNDS privilege" (403) case. */
        public Builder withNoPrivileges() {
            this.merchantPrivileges.clear();
            return this;
        }

        public RefundRequest build() {
            return new RefundRequest(
                    merchantWsApiId,
                    paymentCurrency,
                    new RefundRequest.Amounts(transactionAmount),
                    new RefundRequest.MerchantOrder(transactionReference),
                    new RefundRequest.WsApiSupport(
                            transactionWsApiId,
                            orderWsApiId,
                            wsApiVersion,
                            targetTransactionWsApiId,
                            refundAuthorization
                    ),
                    idempotencyKey,
                    List.copyOf(merchantPrivileges)
            );
        }

        /** The built request serialized as the nested JSON body, for MockMvc/RestAssured. */
        public String json() {
            try {
                return MAPPER.writeValueAsString(build());
            } catch (Exception ex) {
                throw new IllegalStateException("Could not serialize the fixture request", ex);
            }
        }
    }
}
