---
name: lab
description: Report the current lab's identity and status — id, remediation targets, rubric, and time budget, read from .claude/lab.json.
disable-model-invocation: true
---

Read `.claude/lab.json` in the lab root (fall back to reporting "no lab.json found" if absent).

Report to the user, plainly:

- **Lab id:** `<id>`
- **Remediation targets this pass:** `<targets>`
- **Rubric:** `<rubric>` (confirm whether `.claude/<rubric>` actually exists; flag if not)
- **Time budget:** `<minutes>` minutes

This is intentionally a thin status command. It does not orchestrate stage transitions or validate lab structure beyond reading this one file — `/hand-off` and `/grade` already cover stage-close and scoring.
