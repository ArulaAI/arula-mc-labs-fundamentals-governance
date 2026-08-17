#!/usr/bin/env bash
# test_seeded_findings.sh — regression test: confirms each seeded finding's code-level marker
# is still present in the seeded source. Catches an accidental "helpful" fix or refactor that
# silently removes a finding this lab depends on (e.g. someone adds an idempotency check while
# touching RefundService for an unrelated reason, and F2 stops reproducing).
#
# Covers the sixteen seeded findings F1-F16. Some findings are seeded as wrong code and are
# asserted present; others (F2, F12, F13, F14, F15, F16) are seeded by OMISSION and are asserted
# absent.
# An absence check that starts failing is not automatically a bug in this script -- it means
# someone implemented the rule, which for a backlog finding is an undiscussed scope change.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src/main/java/com/mc/pgs/refunds"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

# Prints just the body of RefundService.processOfflineRefund. F12/F13/F14 are seeded by
# OMISSION, so their checks assert an absence -- and an absence assertion is only meaningful if
# it is scoped to the method that should have contained the rule. A whole-file grep would start
# passing/failing for unrelated reasons (e.g. once a Stage-4 F8 fix adds a REFUNDS check to
# RefundService.voidRefund, which is a different method and a different finding).
offline_body() { awk '/public RefundDecision processOfflineRefund/,/^    }$/' "$SRC/service/RefundService.java"; }

# F1: authorization code logged in cleartext
grep -q "log.info(\"Processed offline refund: {}\", record)" "$SRC/service/RefundService.java" \
    && check 0 "F1: RefundService logs the full record (incl. authorizationCode) at INFO" \
    || check 1 "F1: RefundService logs the full record at INFO"

# F2: no idempotency check before insert
! grep -q "findByIdempotencyKey" "$SRC/service/RefundService.java" \
    && check 0 "F2: RefundService.processOfflineRefund does not check idempotency before insert" \
    || check 1 "F2: RefundService.processOfflineRefund does not check idempotency before insert"

# F3: the Void endpoint exists. The path follows the real /card-payments/{id}/... convention;
# it is a documented lab assumption, not a confirmed contract path (the spec pack never
# publishes one, because every Void flow is out of scope) -- see specs/OUT_OF_SCOPE.md. If the
# controller's Void mapping is ever renamed again, this literal must move in the same change or
# F3's regression test silently stops testing anything.
grep -q '@PostMapping("/card-payments/{card_payment_gateway_id}/void")' "$SRC/api/RefundController.java" \
    && check 0 "F3: the Void endpoint still exists (out of scope, registered not removed)" \
    || check 1 "F3: the Void endpoint exists at /card-payments/{card_payment_gateway_id}/void"

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

# F11: the health indicator reports UP without checking anything
HEALTH="$SRC/health/RefundHealthIndicator.java"
[ -f "$HEALTH" ] && check 0 "F11: RefundHealthIndicator.java exists" || check 1 "F11: RefundHealthIndicator.java exists"
grep -q "Health.up()" "$HEALTH" \
    && check 0 "F11: health indicator reports UP" || check 1 "F11: health indicator reports UP"
! grep -qE "Health\.down|DataSource|JdbcTemplate|Dao|\.ping\(|isValid\(" "$HEALTH" \
    && check 0 "F11: health indicator checks nothing before declaring UP (always-UP seed intact)" \
    || check 1 "F11: health indicator now performs a real check -- the always-UP seed has been fixed; update RISK_REGISTER.md/FIXES.md together"

# F12: no REFUNDS privilege gate on the base refund path. Scoped to processOfflineRefund --
# this is deliberately NOT the same finding as F6 (the EXCESSIVE_REFUNDS gate).
! offline_body | grep -qE "RefundPrivilege\.REFUNDS" \
    && check 0 "F12: processOfflineRefund does not gate on the REFUNDS privilege" \
    || check 1 "F12: a REFUNDS privilege gate has appeared in processOfflineRefund -- registered finding, not a fix target"

# F13: no currency-match validation against the original transaction
! offline_body | grep -qE "currency\(\)\.equals|equalsIgnoreCase|currencyMismatch" \
    && check 0 "F13: processOfflineRefund does not validate the refund currency against the original" \
    || check 1 "F13: currency validation has appeared in processOfflineRefund -- registered finding, not a fix target"

# F14: no voided-target rejection
! offline_body | grep -qE '"VOIDED"|isVoided|rejectVoided' \
    && check 0 "F14: processOfflineRefund does not reject a voided target transaction" \
    || check 1 "F14: voided-target rejection has appeared in processOfflineRefund -- registered finding, not a fix target"

# F15: no positive-input validation (amount > 0, currency well-formed) anywhere in the offline path
! offline_body | grep -qE "amountMinor\(\)\s*[<>]|amountMinor\(\)\s*<=|\.isBlank\(\)|@Positive|@NotBlank|IllegalArgumentException.*[Aa]mount|IllegalArgumentException.*[Cc]urrency" \
    && check 0 "F15: processOfflineRefund performs no positive-input validation on amount/currency" \
    || check 1 "F15: input validation has appeared in processOfflineRefund -- registered finding, not a fix target"

# F16: ENABLE_REFUND_REQUESTS / SUPPORT_EXTENDED_REFUNDS declared but never read anywhere in src/main
! grep -rqE "RefundPrivilege\.ENABLE_REFUND_REQUESTS|RefundPrivilege\.SUPPORT_EXTENDED_REFUNDS" "$REPO_ROOT/src/main/java" \
    && check 0 "F16: ENABLE_REFUND_REQUESTS/SUPPORT_EXTENDED_REFUNDS are declared but never referenced by any check" \
    || check 1 "F16: one of the dead-weight privileges is now referenced by a check -- registered finding, not a fix target"

echo "seeded findings tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
