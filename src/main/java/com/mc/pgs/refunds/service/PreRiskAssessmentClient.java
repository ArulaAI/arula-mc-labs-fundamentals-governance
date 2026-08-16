package com.mc.pgs.refunds.service;

import com.mc.pgs.refunds.domain.RefundRequest;
import org.springframework.stereotype.Component;

/**
 * RISK_REGISTER.md finding F4 -- HALLUCINATED DEPENDENCY.
 *
 * pgs-lab-spec-pack.md is explicit: "There is no pre-risk assessment for subsequent refund
 * transactions." Nothing in the Solution Intent, the Modelling page, or the LLD calls for this
 * step. This client was invented during the offline-path build and is wired into
 * RefundService anyway.
 *
 * Action for this lab: REGISTER, do not fix. Leave this class and its call site exactly as
 * seeded -- do not remove it "helpfully." The teaching point is noticing it and registering
 * it, not deleting it (deletion would itself be an undiscussed scope change).
 */
@Component
public class PreRiskAssessmentClient {

    /** Always approves -- there is nothing real behind this call. */
    public boolean assess(RefundRequest request) {
        return true;
    }
}
