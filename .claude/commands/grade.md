---
name: grade
description: Run the lab-grader against .claude/fundamentals.rubric.yaml and report the grade card. Run at the end of the lab, after quality gates have passed.
disable-model-invocation: true
argument-hint: "[--run-id ID]"
allowed-tools: Bash(bash .claude/hooks/lab-grader.sh *)
---

Run the lab grader and report the result to the user.

1. Determine the lab root: `git rev-parse --show-toplevel` (fall back to the current directory).
2. Confirm `.claude/fundamentals.rubric.yaml` exists in the lab root. If it doesn't, tell the user this lab hasn't shipped a rubric yet and stop — do not fabricate a grade.
3. Run:
   ```bash
   bash ".claude/hooks/lab-grader.sh" "<lab_root>" --format both $ARGUMENTS
   ```
4. Present the markdown breakdown to the user directly — don't paraphrase the per-criterion results, show them exactly as the grader reported them (pass/fail, points, title).
5. If the overall percentage is below what the lab's success criteria require (check `LAB_ACTION_GUIDE.md` or `docs/FACILITATOR_KEY.md` if present), say so plainly rather than presenting a low score as a success.
6. Note where the full grade result JSON was written (`.claude/journey/<run_id>.grade.json`) for facilitator review.

Do not modify the rubric, the journey log, or the quality-gates artifact in order to change the outcome of a grade — the grader's job is to report reality, not to be satisfied.
