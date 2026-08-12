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
        authService.resolveRole(authorization);

        sessionStore.reverseHold(holdId);
        return ResponseEntity.ok(Map.of("reversed", holdId));
    }

    @GetMapping("/admin/sessions")
    public ResponseEntity<Collection<InMemorySessionStore.Hold>> sessions() {
        return ResponseEntity.ok(sessionStore.allHolds());
    }
}
