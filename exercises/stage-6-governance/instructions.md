# Stage 6 — Close

**Goal:** evidence, audit trail, grade. Nothing is done until someone who wasn't in the room can
verify it from the artifacts alone.

## Steps

1. Run `mvn verify` — confirm it's fully green: ArchUnit, the compile/test suite, JaCoCo report
   generated.
2. Update `SECURITY.md`: F1, F2, F8 as Security Controls (cite the fix and its `pr-reviewer`
   verdict); F3, F4, F6, F7, F9–F14 as Known Risks; **F5 explicitly marked escalated, not
   defaulted** — its own row, not folded into the others.
3. Confirm `docs/workflow-tracker.md` has a `/hand-off` entry for every stage (0 through 6),
   each one citing the specific artifact filename that stage produced — not a repeated
   template.
4. Run `/grade`. Read the per-criterion breakdown, not just the overall score — a passing grade
   with a failed content check on F5 is not actually a pass of the lab's central lesson.
5. Recap as a group: direct-prompt comprehension vs. the fresh-context review loop; two traced
   fixes plus one mechanically-caught layering fix; a documented backlog including one gap that
   was escalated rather than silently defaulted.

## Acceptance criteria

- [ ] `mvn verify` fully green
- [ ] `SECURITY.md` complete, F5 explicitly marked escalated
- [ ] `docs/workflow-tracker.md` has all 7 stage entries, each citing a real artifact
- [ ] `/grade` run, breakdown reviewed (not just the headline percentage)

## Hand-off

`/hand-off` — cite `SECURITY.md` and the `/grade` output as this stage's artifacts.
