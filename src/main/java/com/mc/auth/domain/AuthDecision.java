package com.mc.auth.domain;

/**
 * The outcome of an authorization decision.
 */
public sealed interface AuthDecision permits AuthDecision.Approved, AuthDecision.Declined {

    record Approved(String authorizationId, String pan, long amountMinor, String currency) implements AuthDecision {
    }

    record Declined(String reason) implements AuthDecision {
    }
}
