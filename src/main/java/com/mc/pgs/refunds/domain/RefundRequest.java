package com.mc.pgs.refunds.domain;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.util.List;

/**
 * Refund request in the real PGS Payment Processor shape, per {@code pgs-lab-spec-pack.md}
 * (Spec 1, "Request field mapping (WSAPI -> Payment Processor API)"). The nesting is faithful
 * to that table rather than flattened for convenience -- the WSAPI-side names a caller would
 * recognise map onto Payment Processor names as follows:
 *
 * <pre>
 *   WSAPI field                        Payment Processor API field
 *   ---------------------------------  ------------------------------------------
 *   merchantId                         merchantWsApiId
 *   transactionId                      wsApiSupport.transactionWsApiId
 *   orderId                            wsApiSupport.orderWsApiId
 *   version                            wsApiSupport.wsApiVersion
 *   transaction.amount                 amounts.transactionAmount
 *   transaction.currency               paymentCurrency
 *   transaction.reference              merchantOrder.transactionReference
 *   transaction.targetTransactionId    wsApiSupport.targetTransactionWsApiId  (capture refunds only)
 *   action.refundAuthorization         wsApiSupport.refundAuthorization       (governs online vs offline)
 * </pre>
 *
 * {@code idempotencyKey} is carried alongside the mapped fields: the spec pack states the
 * idempotency-conflict rule (409 on a repeated request) in its business rules and error table
 * but does not name the transport field, so this lab carries it as a top-level request field.
 * Documented as a lab assumption, not presented as the confirmed production field name.
 *
 * <p><b>Offline vs. online is a request-body decision, not a URL decision.</b> Both endpoints
 * in the real contract accept either kind; {@code wsApiSupport.refundAuthorization} is what
 * selects the behaviour -- see {@link #onlineRefundRequested()}.
 *
 * <p><b>Writing one of these in a test:</b> use
 * {@code com.mc.pgs.refunds.support.RefundRequestFixtures} (test scope) rather than assembling
 * the nested records by hand.
 */
public record RefundRequest(
        String merchantWsApiId,
        String paymentCurrency,
        Amounts amounts,
        MerchantOrder merchantOrder,
        WsApiSupport wsApiSupport,
        String idempotencyKey,
        List<RefundPrivilege> merchantPrivileges
) {

    /** {@code amounts} block -- {@code transaction.amount} on the WSAPI side. */
    public record Amounts(long transactionAmount) {
    }

    /** {@code merchantOrder} block -- {@code transaction.reference} on the WSAPI side. */
    public record MerchantOrder(String transactionReference) {
    }

    /**
     * {@code wsApiSupport} block -- the WSAPI-compatibility fields the Payment Processor
     * carries through so a refund stays linked to its original order and transaction.
     */
    public record WsApiSupport(
            String transactionWsApiId,
            String orderWsApiId,
            String wsApiVersion,
            String targetTransactionWsApiId,
            Boolean refundAuthorization
    ) {
    }

    // ---------------------------------------------------------------------------------------
    // Derived accessors. These exist so the service and persistence layers can read the few
    // values they actually need without every call site walking the nested structure. They are
    // null-safe on purpose: a partially-populated request is a 400 concern at the boundary, not
    // a NullPointerException three layers down.
    //
    // @JsonIgnore on each is load-bearing, not decoration: Jackson treats every no-arg method
    // on a record as an accessor, so without it these would serialize as extra top-level JSON
    // fields and the wire contract would stop matching the spec pack's field-mapping table.
    // ---------------------------------------------------------------------------------------

    /** {@code wsApiSupport.transactionWsApiId} -- the original transaction being refunded. */
    @JsonIgnore
    public String transactionId() {
        return wsApiSupport == null ? null : wsApiSupport.transactionWsApiId();
    }

    /** {@code wsApiSupport.orderWsApiId} -- the original order the refund links back to. */
    @JsonIgnore
    public String orderId() {
        return wsApiSupport == null ? null : wsApiSupport.orderWsApiId();
    }

    /** {@code wsApiSupport.targetTransactionWsApiId} -- populated for capture refunds only. */
    @JsonIgnore
    public String targetTransactionId() {
        return wsApiSupport == null ? null : wsApiSupport.targetTransactionWsApiId();
    }

    /** {@code amounts.transactionAmount} -- the refund amount, in minor units. */
    @JsonIgnore
    public long amountMinor() {
        return amounts == null ? 0L : amounts.transactionAmount();
    }

    /** {@code paymentCurrency}, under the name the rest of this service uses. */
    @JsonIgnore
    public String currency() {
        return paymentCurrency;
    }

    /** {@code merchantWsApiId}, under the name the rest of this service uses. */
    @JsonIgnore
    public String merchantId() {
        return merchantWsApiId;
    }

    /**
     * Whether this request asks for the ONLINE (authorization + downstream settlement) path
     * rather than the OFFLINE one.
     *
     * <p>Per the spec pack's business rules, {@code action.refundAuthorization} is honoured
     * <em>only</em> when the merchant has not opted out via the
     * {@link RefundPrivilege#ENFORCE_REFUNDS_WITHOUT_AUTHORIZATIONS} privilege; when the
     * merchant has opted out, the WSAPI field is ignored and the refund is offline. Absent or
     * {@code false} means offline.
     */
    @JsonIgnore
    public boolean onlineRefundRequested() {
        if (merchantPrivileges != null
                && merchantPrivileges.contains(RefundPrivilege.ENFORCE_REFUNDS_WITHOUT_AUTHORIZATIONS)) {
            return false;
        }
        return wsApiSupport != null && Boolean.TRUE.equals(wsApiSupport.refundAuthorization());
    }
}
