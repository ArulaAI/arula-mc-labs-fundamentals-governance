package com.mc.auth.repo;

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Repository;

/**
 * In-memory hold store and "audit" writer.
 *
 * <p><b>Seeded finding V1 (Critical):</b> {@link #appendAuditLog} writes the
 * full PAN and CVV, in cleartext, to {@code target/auth-audit.log}. It also
 * persists the CVV on {@link Hold} itself — cardholder data that should never
 * be retained past the authorization call. {@code PanTools.mask()} is never
 * called anywhere in this class.
 *
 * <p><b>Seeded finding V3 (High):</b> {@link #createHold} is a classic
 * check-then-act race: when an {@code idempotencyKey} is supplied, it looks
 * up the existing hold and only inserts if absent — but the lookup and the
 * insert are two separate, unsynchronized operations on a
 * {@link ConcurrentHashMap}. Two concurrent retries with the same key can
 * both pass the lookup before either insert lands, producing two holds for
 * one logical authorization. When {@code idempotencyKey} is {@code null},
 * there is no dedup at all — every retry creates a new hold unconditionally.
 */
@Repository
public class InMemorySessionStore {

    private final Map<String, Hold> holdsById = new ConcurrentHashMap<>();
    private final Map<String, String> holdIdByIdempotencyKey = new ConcurrentHashMap<>();

    public record Hold(
            String id,
            String pan,
            String cvv,
            long amountMinor,
            String currency,
            String merchantId,
            String idempotencyKey,
            Instant createdAt
    ) {
    }

    public Hold createHold(String pan, String cvv, long amountMinor, String currency,
                            String merchantId, String idempotencyKey) {
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            // Check-then-act: the read here and the write below are not atomic.
            String existingId = holdIdByIdempotencyKey.get(idempotencyKey);
            if (existingId != null) {
                return holdsById.get(existingId);
            }
        }

        Hold hold = new Hold(
                UUID.randomUUID().toString(),
                pan, cvv, amountMinor, currency, merchantId, idempotencyKey,
                Instant.now()
        );
        holdsById.put(hold.id(), hold);
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            holdIdByIdempotencyKey.put(idempotencyKey, hold.id());
        }
        appendAuditLog(hold);
        return hold;
    }

    public Collection<Hold> allHolds() {
        return List.copyOf(holdsById.values());
    }

    public void reverseHold(String holdId) {
        holdsById.remove(holdId);
    }

    /**
     * Writes the full hold — including PAN and CVV — to
     * {@code target/auth-audit.log}. This is the primary leak path for V1;
     * {@link com.mc.auth.service.PanTools#mask(String)} exists and is correct
     * but is not used here.
     */
    private void appendAuditLog(Hold hold) {
        try {
            Path logDir = Path.of("target");
            Files.createDirectories(logDir);
            Path logFile = logDir.resolve("auth-audit.log");
            String line = "%s AUDIT hold=%s pan=%s cvv=%s amount=%d %s merchant=%s%n".formatted(
                    Instant.now(), hold.id(), hold.pan(), hold.cvv(),
                    hold.amountMinor(), hold.currency(), hold.merchantId());
            try (FileWriter writer = new FileWriter(logFile.toFile(), true)) {
                writer.write(line);
            }
        } catch (IOException e) {
            // Backlog: verbose stack traces / error handling is not hardened yet.
            throw new RuntimeException("audit log write failed", e);
        }
    }
}
