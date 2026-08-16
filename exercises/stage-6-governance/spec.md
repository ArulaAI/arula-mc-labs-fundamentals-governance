# Stage 6 — Spec

## What this stage produces

`mvn verify` green, `SECURITY.md` complete, a full `docs/workflow-tracker.md` audit trail, and a
grade.

## Done means

- `mvn verify` fully green (ArchUnit, tests, JaCoCo report)
- `SECURITY.md`: Security Controls (F1, F2, F8) and Known Risks (F3, F4, F6, F7, F9, F10)
  complete, F5 explicitly marked escalated in its own row
- `docs/workflow-tracker.md`: 7 stage entries, each citing a distinct real artifact filename
- `/grade` run and its per-criterion breakdown reviewed
