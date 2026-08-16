# Stage 0 — Ground: harness and the five failure modes

**Goal:** Shared vocabulary before anyone touches a keyboard, and a confirmed-working harness.
An ungrounded room diverges within ten minutes.

## Steps

1. Facilitator walks the room through: agents vs. skills vs. commands vs. rules (what each
   piece of the `workbench` plugin actually is); model tiers and when to use which; why context
   degrades over a long session; what determinism means when the underlying model is
   probabilistic; why an agent reviewing its own work tends to pass it.
2. The five failure modes, named explicitly — you'll meet all five, firsthand, this lab:
   - **Hallucination** — inventing behavior, fields, or dependencies the spec never mentions
   - **Correctly solving the wrong problem** — building something real and well-engineered that
     was never in scope
   - **Incorrectly solving the right problem** — the right feature, built with a gap the spec's
     edge cases exposed
   - **Sycophancy** — an agent (or a person) reviewing its own work and approving it
   - **Invented dependencies** — adding a call to a service, library, or check that doesn't
     exist on this path
3. Run `/lab`. Confirm it reports lab id `finish-the-refund`, targets `F1, F2`, and a
   120-minute budget.
4. **Confirm a journey event actually landed** in `.claude/journey/` — open the directory, don't
   just trust the command's exit code. On Windows this is where a silent bash/PATH issue would
   otherwise surface at Stage 6 instead of now.

## Acceptance criteria

- [ ] Room can name all five failure modes without looking them up
- [ ] `/lab` reports the correct id, targets, and budget
- [ ] A journey event file exists in `.claude/journey/`

## Hand-off

`/hand-off` — cite the confirmed harness state (journey event present, plugin commands listed)
as this stage's artifact.
