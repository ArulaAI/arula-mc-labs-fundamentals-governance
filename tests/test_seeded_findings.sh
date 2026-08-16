#!/usr/bin/env bash
# test_seeded_findings.sh — regression test: confirms each seeded finding's code-level marker
# is still present in the seeded source. Catches an accidental "helpful" fix or refactor that
# silently removes a finding this lab depends on (e.g. someone adds an idempotency check while
# touching RefundService for an unrelated reason, and F2 stops reproducing).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src/main/java/com/mc/pgs/refunds"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

# F1: authorization code logged in cleartext
grep -q "log.info(\"Processed offline refund: {}\", record)" "$SRC/service/RefundService.java" \
    && check 0 "F1: RefundService logs the full record (incl. authorizationCode) at INFO" \
    || check 1 "F1: RefundService logs the full record at INFO"

# F2: no idempotency check before insert
! grep -q "findByIdempotencyKey" "$SRC/service/RefundService.java" \
    && check 0 "F2: RefundService.processOfflineRefund does not check idempotency before insert" \
    || check 1 "F2: RefundService.processOfflineRefund does not check idempotency before insert"

# F3: void-refunds endpoint exists
grep -q '@PostMapping("/void-refunds")' "$SRC/api/RefundController.java" \
    && check 0 "F3: /void-refunds endpoint still exists (out of scope, registered not removed)" \
    || check 1 "F3: /void-refunds endpoint exists"

# F4: PreRiskAssessmentClient wired into the offline path
grep -q "preRiskAssessmentClient.assess(request)" "$SRC/service/RefundService.java" \
    && check 0 "F4: PreRiskAssessmentClient still called from RefundService" \
    || check 1 "F4: PreRiskAssessmentClient called from RefundService"

# F5: REFUND_EXPIRY exists as a privilege, but no numeric/duration value defined anywhere
grep -q "REFUND_EXPIRY" "$REPO_ROOT/src/main/java/com/mc/pgs/refunds/domain/RefundPrivilege.java" \
    && check 0 "F5: REFUND_EXPIRY privilege exists" || check 1 "F5: REFUND_EXPIRY privilege exists"
! grep -rqE "REFUND_EXPIRY.{0,40}=.{0,20}[0-9]+" "$SRC" \
    && check 0 "F5: no numeric window value defined anywhere near REFUND_EXPIRY" \
    || check 1 "F5: a numeric window value has been defined for REFUND_EXPIRY -- this should stay undefined"

# F8: as-shipped, the controller depends on the repo layer directly -- this is the seed
# ArchitectureIT is designed to catch mechanically at `mvn verify`. This is a cheap, fast
# pre-check of the same fact; it should PASS on a fresh clone (seed present) and only fail if
# someone accidentally fixes F8 without updating this test.
grep -q "RefundRecordDao" "$SRC/api/RefundController.java" \
    && check 0 "F8: RefundController still depends on RefundRecordDao directly (unfixed seed state)" \
    || check 1 "F8: RefundController no longer depends on RefundRecordDao -- if this was an intentional fix, update this test and RISK_REGISTER.md/FIXES.md together"

# F9: hardcoded settlement URL
grep -q "SETTLEMENT_NOTIFY_URL" "$SRC/service/RefundService.java" \
    && check 0 "F9: hardcoded settlement-notify URL still present" \
    || check 1 "F9: hardcoded settlement-notify URL present"

# F10: no @ControllerAdvice actually applied anywhere (a Javadoc comment explaining F10 may
# mention the annotation by name -- that's not usage, so anchor to line-start to exclude it)
! grep -rqE "^\s*@ControllerAdvice" "$REPO_ROOT/src/main/java" \
    && check 0 "F10: no @ControllerAdvice actually applied (inconsistent error shape, registered not fixed)" \
    || check 1 "F10: @ControllerAdvice found applied -- this finding has been fixed, update RISK_REGISTER.md/FIXES.md accordingly"

echo "seeded findings tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
