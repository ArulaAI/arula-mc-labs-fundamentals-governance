# Stage 6 — Governance

**Goal:** Close the loop. Produce a complete, self-contained audit trail that a reviewer
who wasn't in the room could use to trust this session's outcome without replaying it.

## Steps

1. Confirm `docs/workflow-tracker.md` has a hand-off entry for every prior stage (0–5).
   If any are missing or thin, backfill them now from what you actually did — do not
   fabricate detail you don't have; if you're unsure what happened, say so.
2. Write `SECURITY.md` using its template: findings identified (from `RISK_REGISTER.md`),
   findings remediated (from `FIXES.md`), findings deliberately left open, governance
   evidence (journey log path, quality-gate results, review counts), and a pointer to
   `docs/secure-features-guide.md`.
3. Run the grader:
   ```bash
   bash .claude/hooks/lab-grader.sh . --run-id <your-session-id> --format both
   ```
4. Review your score against `.claude/fundamentals.rubric.yaml`. If a criterion failed, decide whether
   it's a real gap (go fix it) or a grading artifact worth noting — either way, don't just
   accept a low score silently.

## Acceptance criteria

- [ ] `docs/workflow-tracker.md` covers all 7 stages with concrete hand-off entries
- [ ] `SECURITY.md` is complete and internally consistent with `RISK_REGISTER.md`/`FIXES.md`
- [ ] The grader has been run and produced a `.claude/journey/<run-id>.grade.json`
- [ ] Every backlog finding is still `Open` in `RISK_REGISTER.md` — nothing was silently
      fixed or silently dropped along the way

## What "done" looks like for the whole lab

Someone with no memory of this session should be able to read `RISK_REGISTER.md`,
`FIXES.md`, `SECURITY.md`, and `docs/workflow-tracker.md`, in that order, and reconstruct
exactly what was found, what was fixed, what was verified, and what remains open — without
needing to ask you anything.
