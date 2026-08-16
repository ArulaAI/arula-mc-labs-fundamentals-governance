package com.mc.pgs.refunds.domain;

/**
 * Merchant privileges from the real PGS spec pack (pgs-lab-spec-pack.md, Spec 1 -- Support
 * Refunds for S2I transactions). All six exist in the real spec; not all are enforced by this
 * service yet -- see the seeded findings in the facilitator key.
 */
public enum RefundPrivilege {
    /** Required for all refunds. */
    REFUNDS,
    /** Allows refunds beyond the captured amount. */
    EXCESSIVE_REFUNDS,
    /** Enables prior-approval refunds. */
    ENABLE_REFUND_REQUESTS,
    /** Offline refund behaviour when the merchant opts out of authorization. */
    ENFORCE_REFUNDS_WITHOUT_AUTHORIZATIONS,
    /** Refunds up to 24 months. */
    SUPPORT_EXTENDED_REFUNDS,
    /**
     * Enforces the allowed refund expiry window.
     *
     * The window's actual value is NOT specified anywhere in the spec pack -- this is
     * deliberate (see specs/refunds-s2i-phase1.spec.md and RISK_REGISTER.md, finding F5). Do
     * not invent a default duration here. The correct response to this gap is to register and
     * escalate it, not to silently pick a value.
     */
    REFUND_EXPIRY
}
