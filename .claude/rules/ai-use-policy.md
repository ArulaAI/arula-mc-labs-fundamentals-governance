# AI Use Policy — Governed Claude Code Usage

This lab is a controlled environment for practicing directed, verified AI usage — not autonomous AI usage. These rules govern how Claude Code is used in this repo.

## 1. Human-in-the-loop on every judgment call

- Claude Code proposes; the participant decides. Findings, plans, fixes, and reviews are inputs to the participant's own judgment, not conclusions to accept by default.
- A subagent's PASS verdict is not the end of the process — the participant is still responsible for confirming the acceptance criteria are actually met.

## 2. Fresh-context review is not optional theater

- The whole point of `pr-reviewer` running in an isolated context is that it does not inherit the framing, confidence, or self-congratulation of the session that wrote the change. Do not paraphrase a fix's rationale into the reviewer's prompt in a way that pre-biases it toward approval.
- If a review comes back with findings, address the findings — do not re-run the same change through review hoping for a different fresh-context outcome without actually changing anything.

## 3. Assumptions must be logged, not silently made

- When an instruction is ambiguous (e.g., a finding's severity is unclear, a rule's scope is unclear), state the assumption made and proceed — do not silently guess and do not block on the ambiguity either.

## 4. No scope creep via AI suggestion

- If Claude Code suggests fixing something beyond the current stage's target findings, that suggestion may be logged (e.g., added to the backlog) but must not be acted on without an explicit, separate decision to do so.

## 5. Everything AI touches is auditable

- Every stage ends with a hand-off entry in `docs/workflow-tracker.md`. This is not paperwork — it is the mechanism by which anyone (a facilitator, a security reviewer, the participant's future self) can reconstruct what AI was asked to do, what it did, and what was verified, without re-running the session.

## 6. Synthetic data only

- This lab's card numbers, CVVs, and identifiers are synthetic. Never introduce real cardholder data, real credentials, or real production data into this repository or into any prompt, regardless of how realistic the lab's data needs to feel.
