# Stage 1 — Spec

## What this stage produces

`RISK_REGISTER.md`, fully populated: all fourteen findings (F1–F14), each with a real affected-file
citation, a severity, a failure mode, and a status.

## Done means

- Fourteen rows, no placeholders
- At least two findings were found with your own eyes before any AI prompt
- At least two decoys were surfaced and explicitly rejected, with a reason
- F5's status is explicit either way

## What's realistic here

We do not expect all fourteen findings found unaided. The honest shape: ~2 found by eye, ~9-10
surfaced when you prompt Claude Code, 2-3 decoys correctly rejected. The AI-surfaced count went
up because F12–F14 are straightforward spec-comparison findings — readily surfaced when Claude
Code is handed the spec and asked to compare it against the code — unlike F5 (the `REFUND_EXPIRY`
window), which stays deliberately hard: an AI review won't flag it because the code looks
reasonable; you only catch it by noticing the spec defines every other privilege's behavior
except this one's threshold value.
