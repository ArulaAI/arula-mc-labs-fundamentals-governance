---
name: hand-off
description: Close out the current lab stage — summarize what was done and append a structured entry to docs/workflow-tracker.md. Run at the end of every stage.
disable-model-invocation: true
---

Close out the current lab stage. There is no `/hand-off` command in the `workbench` plugin
itself (it ships `/journey start|stop|export`, which is a different concept — session-wide
journey capture, not a per-stage narrative record) — this command is this lab's own.

Do the following, in order:

1. **Summarize.** In 3-6 sentences, state: what stage this was, what was accomplished, any
   decisions or assumptions made, any blockers encountered, and what the next stage requires as
   input. Be specific — name the files touched and the artifacts produced, not a generic recap.

2. **Append to `docs/workflow-tracker.md`.** If the file doesn't exist yet, create it with a
   top-level `# Workflow Tracker` heading. Append a new section:

   ```markdown
   ## Stage <N> — <stage name> — <ISO date>

   **Summary:** <the summary from step 1>

   **Artifacts:** <files created/modified this stage>

   **Assumptions/decisions:** <any made, or "none">

   **Blockers:** <any, or "none">
   ```

   Never overwrite or remove a previous stage's entry — this file is an append-only audit
   trail. If a `## Stage <N>` entry for this stage number already exists, you're re-running the
   hand-off for the same stage; append a new dated entry rather than editing the old one.

   **Cite the actual artifact filename that this stage produced** — this is a graded content
   check (`.claude/rubrics/finish-the-refund.rubric.yaml`, `hand-off-not-templated`), not just an
   existence check. A generic "artifacts: various files" entry, or seven copies of the same
   template with only `<N>` changed, will not score — the grader checks for the five distinct
   filenames that should appear across the tracker (`RISK_REGISTER.md`, `plan.md`, `FIXES.md`,
   `secure-features-guide.md`, `SECURITY.md`), not just seven headings.

3. **Confirm** to the user that the hand-off is recorded and name what the next stage should do
   first.

The Write to `docs/workflow-tracker.md` in step 2 is itself captured by the plugin's
`journey_record.py` `PostToolUse` hook — that's sufficient evidence a hand-off happened, no
separate event needs recording by hand.
