package com.mc.pgs.refunds.domain;

/**
 * Sealed outcome of a refund attempt. {@code authorizationCode} on {@link Approved} is the
 * literal sensitive field the spec pack's non-negotiable governs: "the authorization code is
 * nulled out of retrieval responses for online refunds unless the return-authorization-data
 * toggle is ON" -- see RefundService and the FACILITATOR_KEY for where this bites.
 */
public sealed interface RefundDecision permits RefundDecision.Approved, RefundDecision.Declined, RefundDecision.Pending {

    record Approved(String transactionId, long amountMinor, String authorizationCode) implements RefundDecision {
    }

    record Declined(String reason) implements RefundDecision {
    }

    record Pending(String transactionId) implements RefundDecision {
    }
}
