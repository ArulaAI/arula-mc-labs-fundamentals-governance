# Stage 4 — Spec

## What this stage produces

Code fixes for **V1 and V2 only** (`.claude/lab.json` `targets`), plus `FIXES.md` entries,
verified by both security-test slices turning green, `code-to-spec-validator` and
`pr-reviewer` runs, and quality-gate review.

## Done means

- Both security-test slices pass; `BaselineTest.java` still passes
- `FIXES.md` has exactly two entries (V1, V2), each with a validator + reviewer outcome
- Quality gates were run and their output reviewed, not ignored
- Diffs are scoped to their target finding only — no unrelated cleanup bundled in
- V3 and every hygiene-backlog finding remain untouched and still `Open` in `RISK_REGISTER.md`
