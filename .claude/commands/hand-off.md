---
name: hand-off
description: Close out the current lab stage — summarize what was done, append a structured entry to docs/workflow-tracker.md, and record a hand_off journey event. Run at the end of every stage.
disable-model-invocation: true
allowed-tools: Bash(bash .claude/hooks/lib/recorder.sh *)
---

Close out the current lab stage. Do the following, in order:

1. **Summarize.** In 3-6 sentences, state: what stage this was, what was accomplished, any decisions or assumptions made, any blockers encountered, and what the next stage requires as input. Be specific — name the files touched and the artifacts produced, not a generic recap.

2. **Append to `docs/workflow-tracker.md`.** If the file doesn't exist yet, create it with a top-level `# Workflow Tracker` heading. Append a new section:

   ```markdown
   ## Stage <N> — <stage name> — <ISO date>

   **Summary:** <the summary from step 1>

   **Artifacts:** <files created/modified this stage>

   **Assumptions/decisions:** <any made, or "none">

   **Blockers:** <any, or "none">
   ```

   Never overwrite or remove a previous stage's entry — this file is an append-only audit trail. If a `## Stage <N>` entry for this stage number already exists, you're re-running the hand-off for the same stage; append a new dated entry rather than editing the old one.

3. **Record the hand-off event.** Run this, substituting the real values:

   ```bash
   LAB_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
   RUN_ID="<the current session_id if you know it, otherwise omit this step — the journey_record hook already captured this stage's tool calls>"
   bash ".claude/hooks/lib/recorder.sh" "$LAB_ROOT" "$RUN_ID" '"type":"hand_off","stage":"<N>"'
   ```

   If you don't have a reliable `session_id` (it isn't exposed to you directly — it's only visible to hooks via their stdin payload), skip step 3. The write to `docs/workflow-tracker.md` in step 2 is already captured by `.claude/hooks/journey-record.sh` as a `post_tool_use` event, which is sufficient evidence of the hand-off for grading purposes.

4. **Confirm** to the user that the hand-off is recorded and name what the next stage should do first.
