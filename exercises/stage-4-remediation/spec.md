# Stage 4 — Spec

## What this stage produces

F1 and F2 fixed (each with a `FIXES.md` entry and a fresh-context `pr-reviewer` PASS), F8
resolved (`mvn verify` green on ArchUnit), and `processOnlineRefund()` built to spec.

## Done means

- `mvn verify` fully green
- `FIXES.md` has exactly two entries: F1, F2 (F8 gets a `FIXES.md` entry too, since it's
  genuinely fixed this pass even though it isn't a `.claude/lab.json` target)
- `RISK_REGISTER.md` updated: F1, F2, F8 marked `Remediated`; everything else untouched
- Diffs are scoped to their target finding only — no unrelated cleanup bundled in
- F3–F7, F9, F10 remain untouched and still `Open`
