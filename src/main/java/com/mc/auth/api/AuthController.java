package com.mc.auth.api;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import com.mc.auth.domain.AuthDecision;
import com.mc.auth.domain.AuthRequest;
import com.mc.auth.service.AuthService;

import jakarta.validation.Valid;

/**
 * Authorization and preauthorization endpoints.
 *
 * <p><b>Seeded finding V1 (Critical):</b> both endpoints serialize the raw,
 * unmasked PAN into the response body and an {@code X-Card-PAN} header.
 *
 * <p><b>Seeded finding V2 (Critical):</b> the bearer token is resolved via
 * {@link AuthService#resolveRole}, which fails open on a missing/blank
 * token — but neither endpoint actually rejects on the resolved role being
 * absent, since it never is (fail-open always returns a role).
 */
@RestController
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/authorizations")
    public ResponseEntity<AuthDecision> authorize(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AuthRequest request) {
        // Fail-open: resolveRole never actually denies. See AuthService javadoc (V2).
        authService.resolveRole(authorization);

        AuthDecision decision = authService.authorize(request);
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (decision instanceof AuthDecision.Approved approved) {
            // V1: raw PAN echoed back in a response header.
            response.header("X-Card-PAN", approved.pan());
        }
        return response.body(decision);
    }

    @PostMapping("/preauthorizations")
    public ResponseEntity<AuthDecision> preauthorize(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AuthRequest request) {
        authService.resolveRole(authorization);

        AuthDecision decision = authService.authorize(request);
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (decision instanceof AuthDecision.Approved approved) {
            response.header("X-Card-PAN", approved.pan());
        }
        return response.body(decision);
    }
}
