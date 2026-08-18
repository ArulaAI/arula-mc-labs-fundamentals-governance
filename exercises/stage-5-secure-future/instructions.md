# Stage 5 — Look ahead

**Goal:** name what's next without doing it. No code changes this stage.

## Steps

1. Invoke `planner` in guide mode:
   ```text
   Write docs/secure-features-guide.md describing proactive controls to adopt next,
   grounded in this codebase: correlation IDs end to end, wiring up or removing the
   dead-weight ENABLE_REFUND_REQUESTS/SUPPORT_EXTENDED_REFUNDS privileges, config
   externalisation for the settlement-notify URL, deny-by-default validation, and
   structured error handling via @ControllerAdvice. No code changes.
   ```
2. Review it: every recommendation should be grounded in something specific to this codebase
   (a real backlog finding — F7, F9, F10, F11, F16 — or a real gap in the current design), not
   generic security advice that could apply to any service. (Earlier drafts of this stage named
   "tokenisation" as a fifth topic — dropped: nothing in this codebase's actual findings
   motivates it, `RefundRecord` doesn't even carry a card-number field, and asking for it
   contradicted this stage's own acceptance criteria.)

## Acceptance criteria

- [ ] `docs/secure-features-guide.md` exists
- [ ] Every recommendation ties back to something concrete in this codebase
- [ ] No code was changed this stage

## Hand-off

`/hand-off` — cite `docs/secure-features-guide.md` as this stage's artifact.
