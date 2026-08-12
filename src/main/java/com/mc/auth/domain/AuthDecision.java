package com.mc.auth.domain;

/**
 * The outcome of an authorization decision.
 *
 * <p>Seeded finding V1: {@link Approved} currently carries the raw
 * {@code pan}, which {@code AuthController} serializes straight into the
 * response body and an {@code X-Card-PAN} header — see
 * {@code PanTools.mask()}, which exists but is not called on this path.
 */
public sealed interface AuthDecision permits AuthDecision.Approved, AuthDecision.Declined {

    record Approved(String authorizationId, String pan, long amountMinor, String currency) implements AuthDecision {
    }

    record Declined(String reason) implements AuthDecision {
    }
}
