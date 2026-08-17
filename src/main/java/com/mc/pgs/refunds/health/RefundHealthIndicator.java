package com.mc.pgs.refunds.health;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

/**
 * F11 (RISK_REGISTER.md) -- MEANINGLESS HEALTH CHECK.
 *
 * This indicator contributes to {@code /actuator/health} and always reports UP. It checks
 * nothing: not the H2 datasource the refund path cannot function without, not whether
 * {@code refunds.online-refund-enabled} is in a coherent state, not any downstream. It returns
 * UP even when the service is completely unable to process a refund.
 *
 * <p>That makes it worse than having no indicator at all. A health endpoint that cannot fail is
 * an availability signal a load balancer, an orchestrator, and an on-call dashboard will all
 * believe -- so a hard-down refunds service keeps receiving traffic and keeps reporting itself
 * healthy while every request fails.
 *
 * <p>Action for this lab: REGISTER, do not fix. Leave this class exactly as seeded -- like F4,
 * the teaching point is noticing it and registering it, not quietly improving it. A real
 * remediation would assert something falsifiable (a datasource round-trip, a dependency probe)
 * and return DOWN when that assertion fails.
 */
@Component
public class RefundHealthIndicator implements HealthIndicator {

    @Override
    public Health health() {
        // No check of any kind is performed before declaring UP -- this is the finding.
        return Health.up()
                .withDetail("service", "lab-refunds-s2i")
                .withDetail("refunds", "available")
                .build();
    }
}
