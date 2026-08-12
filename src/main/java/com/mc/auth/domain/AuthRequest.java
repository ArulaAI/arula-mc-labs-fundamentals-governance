package com.mc.auth.domain;

import jakarta.validation.constraints.NotBlank;

/**
 * An authorization or preauthorization request.
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
