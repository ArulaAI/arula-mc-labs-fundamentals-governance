#!/usr/bin/env bash
# test_lab_grader.sh — asserts the grader engine is correct AND deterministic
# (same journey file scored twice must produce identical output).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADER="$REPO_ROOT/.claude/hooks/lab-grader.sh"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.claude/journey" "$T/docs/plans"

echo "V1 | PAN exposure | Critical | Open" > "$T/RISK_REGISTER.md"
echo "Step 1 — V1: Critical severity fix" > "$T/docs/plans/plan.md"
printf '## Stage 0\n## Stage 1\n## Stage 2\n## Stage 3\n## Stage 4\n## Stage 5\n## Stage 6\n' > "$T/docs/workflow-tracker.md"
echo '{"gates":{"cardholder-data":"PASS","unknown-dependency":"FAIL"}}' > "$T/.claude/quality-gates-latest.json"
printf '{"type":"subagent_stop"}\n{"type":"subagent_stop"}\n{"type":"subagent_stop"}\n' > "$T/.claude/journey/run_x.jsonl"

cp "$REPO_ROOT/tests/fixtures/fundamentals.rubric.yaml" "$T/.claude/fundamentals.rubric.yaml"

OUT1="$(bash "$GRADER" "$T" --run-id run_x --format json)"
OUT2="$(bash "$GRADER" "$T" --run-id run_x --format json)"

[ "$OUT1" = "$OUT2" ] && check 0 "deterministic: identical output on repeated runs" || check 1 "deterministic: identical output on repeated runs"

echo "$OUT1" | grep -q '"id":"findings-registered".*"passed":true' && check 0 "findings-registered PASSes (file exists)" || check 1 "findings-registered PASSes"
echo "$OUT1" | grep -q '"id":"no-cardholder-data-leak".*"passed":true' && check 0 "no-cardholder-data-leak PASSes (gate=PASS)" || check 1 "no-cardholder-data-leak PASSes"
echo "$OUT1" | grep -q '"id":"no-unverified-dependency".*"passed":false' && check 0 "no-unverified-dependency FAILs (gate=FAIL)" || check 1 "no-unverified-dependency FAILs"
echo "$OUT1" | grep -q '"id":"fresh-context-review-used".*"passed":true' && check 0 "fresh-context-review-used PASSes (3 >= min_count 2)" || check 1 "fresh-context-review-used PASSes"

[ -f "$T/.claude/journey/run_x.grade.json" ] && check 0 "grade.json artifact written" || check 1 "grade.json artifact written"

# --- shell check type: verifies actual runtime state (e.g. mvn test currently passing) ---
T3="$(mktemp -d)"
mkdir -p "$T3/.claude/journey"
cat > "$T3/.claude/fundamentals.rubric.yaml" <<'EOF'
- id: shell-passes
  title: A command that exits 0
  weight: 50
  check: shell
  cmd: true

- id: shell-fails
  title: A command that exits 1, expected to
  weight: 50
  check: shell
  cmd: false
EOF
OUT3="$(bash "$GRADER" "$T3" --run-id run_shell --format json)"
echo "$OUT3" | grep -q '"id":"shell-passes".*"passed":true' && check 0 "shell check: passing command scores passed:true" || check 1 "shell check: passing command scores passed:true"
echo "$OUT3" | grep -q '"id":"shell-fails".*"passed":false' && check 0 "shell check: failing command scores passed:false" || check 1 "shell check: failing command scores passed:false"
rm -rf "$T3"

# Missing rubric must fail loudly (exit 1), not silently produce a fake grade.
T2="$(mktemp -d)"
if bash "$GRADER" "$T2" --format json >/dev/null 2>&1; then
    check 1 "missing rubric exits non-zero rather than fabricating a grade"
else
    check 0 "missing rubric exits non-zero rather than fabricating a grade"
fi
rm -rf "$T2"

echo "lab_grader tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
