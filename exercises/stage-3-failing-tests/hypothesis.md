# Stage 3 — Hypothesis

Before running `mvn verify` for the first time this stage:

**Predict:** you know `ArchitectureIT` has been red since a fresh clone, and you're about to add
two more red tests. How many failures will a single `mvn verify` actually *report* — three, or
fewer?

## My prediction

<!-- Your guess and why. -->

## Confidence

<!-- Low / Medium / High -->

## After running it

The answer is two, not three — and the reason is worth sitting with. Maven stops at the first
failing phase (`test`/surefire) before it ever reaches the later `verify`/failsafe phase where
`ArchitectureIT` lives. F8's red is exactly as real as it was before; it just doesn't get
re-reported once something earlier in the phase order is also red. What does that tell you
about the gap between "what the build reports in one run" and "everything actually wrong"? Is
this specific to Maven, or does it generalize to any tool that's built to stop at the first
failure it hits?
