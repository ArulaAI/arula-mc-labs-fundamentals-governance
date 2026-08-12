package com.mc.auth.api;

import java.util.Collection;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mc.auth.repo.InMemorySessionStore;
import com.mc.auth.service.AuthService;

/**
 * Admin-scoped endpoints.
 *
 * <p><b>Seeded finding V2 (Critical):</b>
 * <ul>
 *   <li>{@link #reverse} resolves a role via {@link AuthService#resolveRole}
 *       (fail-open on a missing/blank token) but never checks the resolved
 *       role actually equals {@code "admin"} — a normal user token
 *       (resolves to {@code "user"}) is accepted here just as an admin
 *       token would be. Privilege escalation.</li>
 *   <li>{@link #sessions} performs no authentication or authorization check
 *       whatsoever — it is a fully unauthenticated dump of every in-memory
 *       hold, including raw PAN and CVV.</li>
 * </ul>
 * There is also no audit record written for either admin action — part of
 * the documented backlog (not fixed in this lab pass).
 */
@RestController
public class AdminController {

    private final AuthService authService;
    private final InMemorySessionStore sessionStore;

    public AdminController(AuthService authService, InMemorySessionStore sessionStore) {
        this.authService = authService;
        this.sessionStore = sessionStore;
    }

    @PostMapping("/admin/reversals")
    public ResponseEntity<Map<String, String>> reverse(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam String holdId) {
        // V2: role is resolved but never checked against "admin".
        authService.resolveRole(authorization);

        sessionStore.reverseHold(holdId);
        return ResponseEntity.ok(Map.of("reversed", holdId));
    }

    @GetMapping("/admin/sessions")
    public ResponseEntity<Collection<InMemorySessionStore.Hold>> sessions() {
        // V2: no authentication check at all on this endpoint.
        return ResponseEntity.ok(sessionStore.allHolds());
    }
}
