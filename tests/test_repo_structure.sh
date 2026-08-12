#!/usr/bin/env bash
# test_repo_structure.sh — validates this repo's structure as a plain,
# self-contained Claude Code repo (no plugin manifest, no .forge/ — see
# README.md "Architecture note"). Supersedes the old plugin-model
# test_plugin_manifests.sh, which checked plugin.json/marketplace.json that
# no longer exist here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

for f in AGENTS.md CLAUDE.md README.md LAB_ACTION_GUIDE.md RISK_REGISTER.md FIXES.md SECURITY.md; do
    [ -f "$REPO_ROOT/$f" ] && check 0 "$f exists" || check 1 "$f exists"
done

for f in docs/FACILITATOR_KEY.md .claude/lab.json .claude/fundamentals.rubric.yaml; do
    [ -f "$REPO_ROOT/$f" ] && check 0 "$f exists" || check 1 "$f exists"
done

if command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/lab.json" \
        && check 0 ".claude/lab.json is valid JSON" || check 1 ".claude/lab.json is valid JSON"
    targets=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).targets.join(','))" "$REPO_ROOT/.claude/lab.json")
    [ "$targets" = "V1,V2" ] && check 0 ".claude/lab.json targets are exactly V1,V2" || check 1 ".claude/lab.json targets are exactly V1,V2 (got: $targets)"
fi

for c in hand-off grade lab; do
    [ -f "$REPO_ROOT/.claude/commands/$c.md" ] && check 0 ".claude/commands/$c.md exists" || check 1 ".claude/commands/$c.md exists"
done

[ "$(cat "$REPO_ROOT/CLAUDE.md" | tr -d '[:space:]')" = "@AGENTS.md" ] && check 0 "CLAUDE.md is the @AGENTS.md one-liner" || check 1 "CLAUDE.md is the @AGENTS.md one-liner"

if command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$REPO_ROOT/.claude/settings.json" \
        && check 0 ".claude/settings.json is valid JSON" || check 1 ".claude/settings.json is valid JSON"
else
    echo "SKIP: node not available — settings.json validity not checked" >&2
fi

# Every agent file has required frontmatter
for a in .claude/agents/planner.md .claude/agents/code-to-spec-validator.md .claude/agents/pr-reviewer.md; do
    grep -q '^name:' "$REPO_ROOT/$a" && check 0 "$a has name: frontmatter" || check 1 "$a has name: frontmatter"
    grep -q '^description:' "$REPO_ROOT/$a" && check 0 "$a has description: frontmatter" || check 1 "$a has description: frontmatter"
done
grep -q 'disallowedTools:.*Write' "$REPO_ROOT/.claude/agents/pr-reviewer.md" && check 0 "pr-reviewer.md structurally disallows Write" || check 1 "pr-reviewer.md structurally disallows Write"
grep -q 'disallowedTools:.*Edit' "$REPO_ROOT/.claude/agents/pr-reviewer.md" && check 0 "pr-reviewer.md structurally disallows Edit" || check 1 "pr-reviewer.md structurally disallows Edit"

# Every hook script referenced in settings.json actually exists
for script in journey-record.sh quality-gates.sh lab-grader.sh; do
    [ -f "$REPO_ROOT/.claude/hooks/$script" ] && check 0 ".claude/hooks/$script exists" || check 1 ".claude/hooks/$script exists"
done

# No leftover Forge-pattern artifacts from before the architecture pivot
[ ! -d "$REPO_ROOT/.forge" ] && check 0 "no .forge/ directory (plain-repo pattern, not manifest-vendored)" || check 1 "no .forge/ directory (plain-repo pattern, not manifest-vendored)"
[ ! -d "$REPO_ROOT/.github" ] && check 0 "no .github/ directory (Claude-only scope)" || check 1 "no .github/ directory (Claude-only scope)"

# All 7 exercise stages have the full instructions/spec/hypothesis triad
for stage in stage-0-setup stage-1-comprehend-register stage-2-plan stage-3-failing-tests stage-4-remediation stage-5-secure-future stage-6-governance; do
    for f in instructions.md spec.md hypothesis.md; do
        [ -f "$REPO_ROOT/exercises/$stage/$f" ] && check 0 "exercises/$stage/$f exists" || check 1 "exercises/$stage/$f exists"
    done
done

echo "repo structure tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
