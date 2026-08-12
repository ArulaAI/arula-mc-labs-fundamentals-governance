package com.mc.auth.domain;

import jakarta.validation.constraints.NotBlank;

/**
 * An authorization or preauthorization request.
 *
 * {@code idempotencyKey} is intentionally nullable — the seeded service does
 * not yet enforce it (see the lab's V3 finding).
 */
public record AuthRequest(
        @NotBlank String pan,
        @NotBlank String cvv,
        @NotBlank String expiry,
        long amountMinor,
        @NotBlank String currency,
        @NotBlank String merchantId,
        String idempotencyKey
) {
}
