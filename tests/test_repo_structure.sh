#!/usr/bin/env bash
# test_repo_structure.sh — validates this repo's structure as a plugin-consuming Claude Code
# repo (depends on the `workbench` plugin installed from the marketplace -- see AGENTS.md
# "Prerequisites"). Supersedes the earlier self-contained-bash-hooks version: this repo no
# longer commits its own .claude/agents/, .claude/rules/, or .claude/hooks/ -- those come from
# the plugin now, and a repo-local copy would shadow/conflict with it.
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

if command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/lab.json" \
        && check 0 ".claude/lab.json is valid JSON" || check 1 ".claude/lab.json is valid JSON"
    targets=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).targets.join(','))" "$REPO_ROOT/.claude/lab.json")
    [ "$targets" = "F1,F2" ] && check 0 ".claude/lab.json targets are exactly F1,F2" || check 1 ".claude/lab.json targets are exactly F1,F2 (got: $targets)"
    rubric_path=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).rubric)" "$REPO_ROOT/.claude/lab.json")
    [ "$rubric_path" = ".claude/rubrics/finish-the-refund.rubric.yaml" ] && check 0 ".claude/lab.json rubric path matches the shipped rubric" || check 1 ".claude/lab.json rubric path matches the shipped rubric (got: $rubric_path)"

    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/settings.json" \
        && check 0 ".claude/settings.json is valid JSON" || check 1 ".claude/settings.json is valid JSON"
    journey_dir=$(node -e "console.log((JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).env||{}).WORKBENCH_JOURNEY_DIR||'')" "$REPO_ROOT/.claude/settings.json")
    [ "$journey_dir" = ".claude/journey" ] && check 0 "settings.json sets WORKBENCH_JOURNEY_DIR=.claude/journey" || check 1 "settings.json sets WORKBENCH_JOURNEY_DIR=.claude/journey (got: '$journey_dir')"

    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/gate-guard.json" \
        && check 0 ".claude/gate-guard.json is valid JSON" || check 1 ".claude/gate-guard.json is valid JSON"
    denies_reference=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).deny.includes('reference/**'))" "$REPO_ROOT/.claude/gate-guard.json")
    [ "$denies_reference" = "true" ] && check 0 ".claude/gate-guard.json denies reference/**" || check 1 ".claude/gate-guard.json denies reference/**"
else
    echo "SKIP: node not available -- JSON content checks not run" >&2
fi

# Only /hand-off is repo-local -- /lab and /grade come from the plugin now. A repo-local
# lab.md or grade.md would shadow the plugin's real ones and is a regression, not a feature.
[ -f "$REPO_ROOT/.claude/commands/hand-off.md" ] && check 0 ".claude/commands/hand-off.md exists (repo-local, no plugin equivalent)" || check 1 ".claude/commands/hand-off.md exists"
[ ! -f "$REPO_ROOT/.claude/commands/lab.md" ] && check 0 "no repo-local lab.md shadowing the plugin's /lab" || check 1 "no repo-local lab.md shadowing the plugin's /lab"
[ ! -f "$REPO_ROOT/.claude/commands/grade.md" ] && check 0 "no repo-local grade.md shadowing the plugin's /grade" || check 1 "no repo-local grade.md shadowing the plugin's /grade"

[ "$(cat "$REPO_ROOT/CLAUDE.md" | tr -d '[:space:]')" = "@AGENTS.md" ] && check 0 "CLAUDE.md is the @AGENTS.md one-liner" || check 1 "CLAUDE.md is the @AGENTS.md one-liner"

# No leftover repo-local agents/rules/hooks -- these must come from the plugin, not a local
# copy that can silently drift out of sync with it.
[ ! -d "$REPO_ROOT/.claude/agents" ] && check 0 "no repo-local .claude/agents/ (plugin-provided)" || check 1 "no repo-local .claude/agents/ (plugin-provided)"
[ ! -d "$REPO_ROOT/.claude/rules" ] && check 0 "no repo-local .claude/rules/ (plugin-provided)" || check 1 "no repo-local .claude/rules/ (plugin-provided)"
[ ! -d "$REPO_ROOT/.claude/hooks" ] && check 0 "no repo-local .claude/hooks/ (plugin-provided)" || check 1 "no repo-local .claude/hooks/ (plugin-provided)"
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
