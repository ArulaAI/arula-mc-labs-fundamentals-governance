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
        authService.resolveRole(authorization);

        AuthDecision decision = authService.authorize(request);
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (decision instanceof AuthDecision.Approved approved) {
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
