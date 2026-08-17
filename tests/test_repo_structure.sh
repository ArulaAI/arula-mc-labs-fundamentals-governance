#!/usr/bin/env bash
# test_repo_structure.sh — validates this repo's structure as a plugin-consuming Claude Code
# repo (depends on the `workbench` plugin installed from the marketplace -- see AGENTS.md
# "Prerequisites").
#
# The rule this file enforces is narrower than it used to be, and the narrowing is deliberate.
# The old rule was a blanket ban on repo-local .claude/agents/, .claude/rules/ and
# .claude/hooks/. The real risk was never "a local file exists"; it was "a local file DUPLICATES
# something the plugin also provides, and the two silently drift apart". So the rule is now:
#
#   repo-local components are forbidden only where they would duplicate plugin-provided
#   functionality.
#
# .claude/hooks/gate_guard.py is the documented exception. The plugin ships no blocking hook at
# all -- quality_gates.py reports, it does not block -- so there is nothing for gate_guard.py to
# drift out of sync with, and without it reference/ is not actually gated during a live session.
# Same reasoning for .claude/scripts/grade_repo.py: the plugin's grader does not implement the
# content checks this repo's rubric needs, so the local one is a stopgap, not a duplicate.
# .claude/agents/ and .claude/rules/ ARE plugin-provided, so those stay banned below.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

for f in AGENTS.md CLAUDE.md README.md LAB_ACTION_GUIDE.md RISK_REGISTER.md FIXES.md SECURITY.md; do
    [ -f "$REPO_ROOT/$f" ] && check 0 "$f exists" || check 1 "$f exists"
done

for f in docs/FACILITATOR_KEY.md .claude/lab.json .claude/rubrics/finish-the-refund.rubric.yaml .claude/gate-guard.json .claude/settings.json; do
    [ -f "$REPO_ROOT/$f" ] && check 0 "$f exists" || check 1 "$f exists"
done

# NOTE on the node snippets below: they use process.stdout.write, not console.log. console.log
# runs non-string values through util.inspect, and Node 26 emits ANSI colour codes even when
# stdout is a pipe -- so $(node -e "console.log(true)") captures an escape-wrapped string that
# never equals "true". Found here as two silently-failing checks. Keep them as raw writes.
if command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/lab.json" \
        && check 0 ".claude/lab.json is valid JSON" || check 1 ".claude/lab.json is valid JSON"
    targets=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).targets.join(',')))" "$REPO_ROOT/.claude/lab.json")
    [ "$targets" = "F1,F2" ] && check 0 ".claude/lab.json targets are exactly F1,F2" || check 1 ".claude/lab.json targets are exactly F1,F2 (got: $targets)"
    rubric_path=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).rubric))" "$REPO_ROOT/.claude/lab.json")
    [ "$rubric_path" = ".claude/rubrics/finish-the-refund.rubric.yaml" ] && check 0 ".claude/lab.json rubric path matches the shipped rubric" || check 1 ".claude/lab.json rubric path matches the shipped rubric (got: $rubric_path)"

    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/settings.json" \
        && check 0 ".claude/settings.json is valid JSON" || check 1 ".claude/settings.json is valid JSON"
    journey_dir=$(node -e "process.stdout.write(String((JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).env||{}).WORKBENCH_JOURNEY_DIR||''))" "$REPO_ROOT/.claude/settings.json")
    [ "$journey_dir" = ".claude/journey" ] && check 0 "settings.json sets WORKBENCH_JOURNEY_DIR=.claude/journey" || check 1 "settings.json sets WORKBENCH_JOURNEY_DIR=.claude/journey (got: '$journey_dir')"

    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/gate-guard.json" \
        && check 0 ".claude/gate-guard.json is valid JSON" || check 1 ".claude/gate-guard.json is valid JSON"
    denies_reference=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).deny.includes('reference/**')))" "$REPO_ROOT/.claude/gate-guard.json")
    [ "$denies_reference" = "true" ] && check 0 ".claude/gate-guard.json denies reference/**" || check 1 ".claude/gate-guard.json denies reference/**"
else
    echo "SKIP: node not available -- JSON content checks not run" >&2
fi

# Only /hand-off is repo-local -- /lab and /grade come from the plugin now. A repo-local
# lab.md or grade.md WOULD duplicate a plugin command and shadow it, which is exactly the
# failure the narrowed rule is about. grade_repo.py is documented as a fallback to run directly,
# not wired up as a shadowing /grade command.
[ -f "$REPO_ROOT/.claude/commands/hand-off.md" ] && check 0 ".claude/commands/hand-off.md exists (repo-local, no plugin equivalent)" || check 1 ".claude/commands/hand-off.md exists"
[ ! -f "$REPO_ROOT/.claude/commands/lab.md" ] && check 0 "no repo-local lab.md shadowing the plugin's /lab" || check 1 "no repo-local lab.md shadowing the plugin's /lab"
[ ! -f "$REPO_ROOT/.claude/commands/grade.md" ] && check 0 "no repo-local grade.md shadowing the plugin's /grade" || check 1 "no repo-local grade.md shadowing the plugin's /grade"

[ "$(cat "$REPO_ROOT/CLAUDE.md" | tr -d '[:space:]')" = "@AGENTS.md" ] && check 0 "CLAUDE.md is the @AGENTS.md one-liner" || check 1 "CLAUDE.md is the @AGENTS.md one-liner"

# Agents and rules ARE plugin-provided, so a repo-local copy would duplicate and drift.
[ ! -d "$REPO_ROOT/.claude/agents" ] && check 0 "no repo-local .claude/agents/ (plugin-provided)" || check 1 "no repo-local .claude/agents/ (plugin-provided)"
[ ! -d "$REPO_ROOT/.claude/rules" ] && check 0 "no repo-local .claude/rules/ (plugin-provided)" || check 1 "no repo-local .claude/rules/ (plugin-provided)"

# .claude/hooks/ is NOT banned outright -- only hooks that duplicate a plugin hook are. The one
# file allowed here is gate_guard.py, which has no plugin equivalent. Anything else appearing in
# this directory is the drift risk the rule exists to prevent, so it fails.
if [ -d "$REPO_ROOT/.claude/hooks" ]; then
    unexpected=$(find "$REPO_ROOT/.claude/hooks" -maxdepth 1 -type f ! -name 'gate_guard.py' ! -name '.gitkeep' | wc -l | tr -d ' ')
    [ "$unexpected" = "0" ] && check 0 ".claude/hooks/ contains only the documented gate_guard.py exception" || check 1 ".claude/hooks/ contains $unexpected file(s) beyond gate_guard.py -- a repo-local hook is only allowed where the plugin has no equivalent"
fi

# The two lab-local stopgaps must actually be present -- without gate_guard.py, reference/ is
# not gated; without grade_repo.py, there is no grading fallback when the plugin is absent.
[ -f "$REPO_ROOT/.claude/hooks/gate_guard.py" ] && check 0 ".claude/hooks/gate_guard.py exists (blocking gate; no plugin equivalent)" || check 1 ".claude/hooks/gate_guard.py exists"
[ -f "$REPO_ROOT/.claude/scripts/grade_repo.py" ] && check 0 ".claude/scripts/grade_repo.py exists (grading fallback)" || check 1 ".claude/scripts/grade_repo.py exists"
[ -f "$REPO_ROOT/.claude/scripts/anti_gaming_check.py" ] && check 0 ".claude/scripts/anti_gaming_check.py exists (leak-reintroduction check)" || check 1 ".claude/scripts/anti_gaming_check.py exists"
[ -f "$REPO_ROOT/.claude/fixtures/f5-refund-expiry.json" ] && check 0 ".claude/fixtures/f5-refund-expiry.json exists (F5 seed-integrity fixture)" || check 1 ".claude/fixtures/f5-refund-expiry.json exists"
[ -f "$REPO_ROOT/.claude/fixtures/f1-log-leak.json" ] && check 0 ".claude/fixtures/f1-log-leak.json exists (F1 leak-reintroduction fixture)" || check 1 ".claude/fixtures/f1-log-leak.json exists"

# The hook is only real if it is actually wired into settings.json.
if command -v node >/dev/null 2>&1; then
    wired=$(node -e "
      const s=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
      const pre=((s.hooks||{}).PreToolUse)||[];
      process.stdout.write(String(pre.some(g=>(g.hooks||[]).some(h=>String(h.command||'').includes('gate_guard.py')))));
    " "$REPO_ROOT/.claude/settings.json")
    [ "$wired" = "true" ] && check 0 "settings.json wires gate_guard.py as a PreToolUse hook" || check 1 "settings.json wires gate_guard.py as a PreToolUse hook"
fi

# And it is only trustworthy if it still blocks every bypass class it was written for.
if command -v python3 >/dev/null 2>&1; then
    python3 "$REPO_ROOT/.claude/hooks/gate_guard.py" --self-test >/dev/null 2>&1 \
        && check 0 "gate_guard.py --self-test passes (all four bypass classes blocked)" \
        || check 1 "gate_guard.py --self-test FAILED -- run it directly to see which bypass class regressed"
fi

# F11's seed and its dependency
[ -f "$REPO_ROOT/src/main/java/com/mc/pgs/refunds/health/RefundHealthIndicator.java" ] && check 0 "F11 seed RefundHealthIndicator.java exists" || check 1 "F11 seed RefundHealthIndicator.java exists"
grep -q "spring-boot-starter-actuator" "$REPO_ROOT/pom.xml" && check 0 "pom.xml declares spring-boot-starter-actuator (F11's /actuator/health surface)" || check 1 "pom.xml declares spring-boot-starter-actuator"

# The Stage 3 fixture builder -- participants must not be hand-assembling the nested request.
[ -f "$REPO_ROOT/src/test/java/com/mc/pgs/refunds/support/RefundRequestFixtures.java" ] && check 0 "RefundRequestFixtures.java exists (Stage 3 test-fixture builder)" || check 1 "RefundRequestFixtures.java exists"

# Endpoints follow the real PGS contract shape, and the F3 Void path matches what
# tests/test_seeded_findings.sh greps for. These two drifting apart is how F3's regression test
# silently stops testing anything.
CTRL="$REPO_ROOT/src/main/java/com/mc/pgs/refunds/api/RefundController.java"
grep -q '@PostMapping("/card-payments/{card_payment_gateway_id}/refunds")' "$CTRL" && check 0 "controller exposes the real PAYMENT-refund endpoint" || check 1 "controller exposes the real PAYMENT-refund endpoint"
grep -q '@PostMapping("/card-payments/{card_payment_gateway_id}/card-captures/{card_transaction_gateway_id}/refunds")' "$CTRL" && check 0 "controller exposes the real CAPTURE-refund endpoint" || check 1 "controller exposes the real CAPTURE-refund endpoint"
! grep -qE '@PostMapping\("/refunds/(offline|online)"\)' "$CTRL" && check 0 "the old simplified /refunds/offline|online stand-ins are gone" || check 1 "the old simplified /refunds/offline|online stand-ins are still present"
void_path=$(grep -oE '@PostMapping\("[^"]*void[^"]*"\)' "$CTRL" | head -1)
grep -q "$void_path" "$REPO_ROOT/tests/test_seeded_findings.sh" && check 0 "F3's Void path in the controller matches what test_seeded_findings.sh greps for" || check 1 "F3's Void path drifted from test_seeded_findings.sh -- rename them in the same change or F3's regression test stops testing anything"

[ ! -f "$REPO_ROOT/.claude/fundamentals.rubric.yaml" ] && check 0 "old fundamentals.rubric.yaml removed" || check 1 "old fundamentals.rubric.yaml removed"

# No leftover old-domain source
[ ! -d "$REPO_ROOT/src/main/java/com/mc/auth" ] && check 0 "no leftover com.mc.auth source" || check 1 "no leftover com.mc.auth source"
[ -d "$REPO_ROOT/src/main/java/com/mc/pgs/refunds" ] && check 0 "com.mc.pgs.refunds source exists" || check 1 "com.mc.pgs.refunds source exists"

# Only one build-instructions doc for this lab -- not a stale internal one contradicting the
# canonical top-level one.
[ ! -f "$REPO_ROOT/docs/Lab1_Build_Instructions_Foundations_Governance.md" ] && check 0 "no stale internal build-instructions doc" || check 1 "no stale internal build-instructions doc"

# ArchUnit and failsafe are actually wired -- this is what makes F8 build-blocking real.
grep -q "archunit-junit5" "$REPO_ROOT/pom.xml" && check 0 "pom.xml declares archunit-junit5" || check 1 "pom.xml declares archunit-junit5"
grep -q "maven-failsafe-plugin" "$REPO_ROOT/pom.xml" && check 0 "pom.xml wires maven-failsafe-plugin" || check 1 "pom.xml wires maven-failsafe-plugin"
[ -f "$REPO_ROOT/src/test/java/com/mc/pgs/refunds/ArchitectureIT.java" ] && check 0 "ArchitectureIT.java exists (*IT, runs at verify not test)" || check 1 "ArchitectureIT.java exists"

# All 7 exercise stages have the full instructions/spec/hypothesis triad
for stage in stage-0-setup stage-1-comprehend-register stage-2-plan stage-3-failing-tests stage-4-remediation stage-5-secure-future stage-6-governance; do
    for f in instructions.md spec.md hypothesis.md; do
        [ -f "$REPO_ROOT/exercises/$stage/$f" ] && check 0 "exercises/$stage/$f exists" || check 1 "exercises/$stage/$f exists"
    done
done

# reference/ fallback exists and is gated
[ -f "$REPO_ROOT/reference/README.md" ] && check 0 "reference/README.md exists" || check 1 "reference/README.md exists"

echo "repo structure tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
