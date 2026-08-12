# Stage 0 — Context and the Five Failure Modes

**Goal:** a shared understanding of the five failure modes and governed Claude Code usage,
before any code is touched. This stage is facilitator-led — no code yet.

See [`LAB_ACTION_GUIDE.md`](../../LAB_ACTION_GUIDE.md) Stage 0 for the exact framing.

## Steps

1. Facilitator introduces the payments scenario: a real-time, high-TPS card
   authorization service, and why it must never leak cardholder data, must fail closed on
   authorization, and must not double-hold funds on retry.
2. Facilitator names the five failure modes this lab is built to make visible:
   - **Hallucination** — inventing a dependency or API that doesn't exist
   - **Correctly solving the wrong problem** — fixing the symptom while the real leak persists elsewhere
   - **Incorrectly solving the right problem** — a fix that doesn't actually close the finding
   - **Self-congratulation in review** — an in-session self-review tends to pass because the author already believes it's correct
   - **Invented dependencies** — a payments-specific case of hallucination worth calling out on its own
3. Confirm the harness is loaded: run `/lab`. It should report lab id
   `fundamentals-governance`, targets `V1, V2`, and a 120-minute budget, read from
   `.claude/lab.json`.
4. Read `.claude/rules/payments-guardrails.md` and `.claude/rules/ai-use-policy.md` — these
   apply to every later stage without being restated.

## Acceptance criteria

- [ ] The five failure modes have been named and discussed, not just read silently
- [ ] `/lab` reports the correct id, targets, and time budget
- [ ] No source file under `src/main/java/` has been opened yet for anything beyond context

## What NOT to do yet

Do not open `AuthService.java`, `AuthController.java`, `AdminController.java`, or
`InMemorySessionStore.java` looking for bugs yet — that's Stage 1.
