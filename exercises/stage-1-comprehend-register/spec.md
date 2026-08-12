# Stage 1 — Spec

## What this stage produces

`RISK_REGISTER.md`, populated per its template (see repo root). Every finding gets:
severity, location, description, impact, status.

## Done means

- ≥ 3 findings registered with concrete `<file>:<region>` locations, not vague areas
- Severities assigned and internally consistent (a fail-open auth bug isn't "Low")
- At least one item is explicitly left `Open` as backlog, not silently omitted
- No source file under `src/main/java/` has been modified
- A hand-off entry exists in `docs/workflow-tracker.md`
