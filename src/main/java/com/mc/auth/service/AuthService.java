package com.mc.auth.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.mc.auth.domain.AuthDecision;
import com.mc.auth.domain.AuthRequest;
import com.mc.auth.repo.InMemorySessionStore;

/**
 * Authorization decisioning and role resolution.
 *
 * <p><b>Seeded finding V1 (Critical):</b> {@link #authorize} logs the full
 * PAN and CVV at INFO, and returns them unmasked in the {@link AuthDecision}
 * ({@link com.mc.auth.api.AuthController} then serializes that straight into
 * the response body and an {@code X-Card-PAN} header).
 * {@link PanTools#mask(String)} exists and is correct but is never called
 * here.
 *
 * <p><b>Seeded finding V2 (Critical):</b> {@link #resolveRole} fails open —
 * a missing or blank bearer token resolves to {@code "admin"} instead of
 * being rejected. Any non-blank token resolves to {@code "user"} with no
 * real verification. Callers ({@code AuthController}, {@code AdminController})
 * compound this by never checking the resolved role is actually
 * {@code "admin"} before performing admin-scoped actions.
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final InMemorySessionStore sessionStore;

    public AuthService(InMemorySessionStore sessionStore) {
        this.sessionStore = sessionStore;
    }

    public AuthDecision authorize(AuthRequest request) {
        log.info("Authorizing pan={} cvv={} amount={} {} merchant={} idempotencyKey={}",
                request.pan(), request.cvv(), request.amountMinor(), request.currency(),
                request.merchantId(), request.idempotencyKey());

        InMemorySessionStore.Hold hold = sessionStore.createHold(
                request.pan(), request.cvv(), request.amountMinor(), request.currency(),
                request.merchantId(), request.idempotencyKey());

        return new AuthDecision.Approved(hold.id(), request.pan(), request.amountMinor(), request.currency());
    }

    /**
     * Resolves a caller's role from a bearer token. Fails OPEN: no token, or
     * a blank token, resolves to {@code "admin"} rather than being denied.
     */
    public String resolveRole(String bearerToken) {
        if (bearerToken == null || bearerToken.isBlank()) {
            return "admin";
        }
        return "user";
    }
}
