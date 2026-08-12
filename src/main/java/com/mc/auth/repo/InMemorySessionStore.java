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
 * In-memory hold store and audit writer.
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
     * Writes the hold to {@code target/auth-audit.log}.
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
            throw new RuntimeException("audit log write failed", e);
        }
    }
}
