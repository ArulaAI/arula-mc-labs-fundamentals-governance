---
paths:
  - "**/*.java"
  - "pom.xml"
---

# Java / Spring Boot Coding Standards

Baseline standards for `.java` sources and `pom.xml` in this lab. Applied on top of, never in place of, `payments-guardrails.md`.

## Language & framework baseline

- Java 21 language features are fine to use (records, sealed interfaces/classes, pattern matching in `switch`) — the codebase already uses records for request/response types and a sealed interface for authorization decisions. Match that style rather than introducing an alternative shape (e.g., a plain class hierarchy) for new code in the same domain.
- Spring Boot 3.3.x conventions: constructor injection over field injection, `@ConfigurationProperties` over scattered `@Value`, explicit `@Bean` wiring over classpath magic where the existing code already does so.

## Error handling

- Never let a raw exception's message or stack trace reach an HTTP response body. Map to a defined error response shape.
- Never swallow an exception silently (empty `catch` block, `catch (Exception e) {}`). At minimum, log at an appropriate level with context — but see `payments-guardrails.md` §1 before logging anything that might contain cardholder data.
- Prefer specific exception types over broad `catch (Exception e)` unless the boundary genuinely requires it (e.g., a top-level request handler).

## Testing

- New tests are JUnit 5 + MockMvc (or the existing test stack in this module — check before introducing a different one).
- A security test must assert the **secure** behavior and therefore be red before the fix and green after. A test that only encodes the current (possibly insecure) behavior is not a security test.
- Deterministic tests only — no `Thread.sleep`-based timing assumptions, no reliance on wall-clock or external state that isn't controlled by the test.

## Dependencies

- Every dependency used in code must already be declared in `pom.xml`. Before writing an import, confirm it resolves against a real, declared dependency — see `payments-guardrails.md` §4 on invented dependencies. This is not a style preference; unresolvable imports are a build-breaking, and in this lab a deliberately-tested, failure mode.

## Diff hygiene

- Match existing formatting and import ordering in the file being edited rather than reformatting the whole file.
- Do not introduce new dependencies, new configuration files, or new architectural layers to fix a single, narrowly-scoped finding.
