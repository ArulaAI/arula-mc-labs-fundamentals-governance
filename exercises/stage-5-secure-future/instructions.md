# Stage 5 — Secure Future

**Goal:** Document proactive controls worth adopting next — no code changes. This stage is
a roadmap, not an implementation.

## Steps

1. Invoke the `planner` subagent in Mode 2 (secure-future guide).
2. `planner` should ground every proposed control in what actually exists in this
   codebase — e.g., the unenforced `idempotencyKey` field is a concrete anchor for an
   idempotency-enforcement control; generic "add rate limiting" advice disconnected from
   the code is not what this stage is for.
3. Review the output in `docs/secure-features-guide.md`. For each control, confirm you
   understand *why* it matters for this specific service, not just that it sounds like
   good practice in general.
4. Do not implement any of the proposed controls in this stage — that would be scope creep
   past this lab's remediation target (`.claude/rules/ai-use-policy.md` §4).

## Acceptance criteria

- [ ] `docs/secure-features-guide.md` exists, matching the template in `spec-template.md`
- [ ] Each control names what it is, why it matters *for this service*, and where it plugs in
- [ ] No implementation code accompanies this document
- [ ] No production code was modified in this stage

## Hand-off

Log in `docs/workflow-tracker.md`: how many controls were proposed, and any you
deliberately excluded (and why).
