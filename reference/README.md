# Reference solution — Stage 4 end state

This folder is **gated**: the `workbench` plugin's `gate_guard.py` hook blocks any write here
during a live session (`.claude/gate-guard.json` denies `reference/**`). If your group is behind
by the 20-minute mark of Stage 4, ask your facilitator to walk you through this folder rather
than rushing the fresh-context review step.

This is the solved state after F1, F2, and F8 are fixed and `processOnlineRefund()` is built --
i.e., where a group should be at the end of Stage 4. It is not a copy-paste shortcut: reading it
and understanding *why* each change closes its finding is the point. Facilitators: confirm a
group actually explains the diff back to you before pointing them here, don't just hand it over.

- `RefundService.solved.java` — F1 fix (no cleartext authorization code in logs), F2 fix
  (idempotency check returns 409 instead of a duplicate), plus `processOnlineRefund()` built
  (toggle-gated, nulls the authorization code unless the return-auth-data toggle is ON, does not
  write settlement records).
- `RefundController.solved.java` — F8 fix: the privilege check and DAO access that used to live
  directly in the controller now delegate to `RefundService.voidRefund(...)`; the controller no
  longer depends on `RefundRecordDao` at all, which is what makes `ArchitectureIT` go green.

F3, F4, F5, F6, F7, F9, F10 are unchanged from the seeded state in this reference -- they stay
registered/backlog, exactly as the lab intends. If your `RISK_REGISTER.md` still lists them, that
is correct, not something to fix.
