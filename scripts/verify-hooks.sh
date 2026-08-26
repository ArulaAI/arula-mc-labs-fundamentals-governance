#!/usr/bin/env bash
# ===========================================================================
# verify-hooks.sh -- Pre-session hook smoke test for Lab 1
#
# Run from the repo root:
#   bash scripts/verify-hooks.sh
#
# What it does:
#   1. Locates the workbench plugin and runs its resolve-python script
#   2. Verifies the Python path cache was created and is usable
#   3. Checks that pyyaml is importable (needed by the grader)
#   4. Fires each plugin hook event via run-python with realistic payloads
#   5. Runs the repo-local gate_guard.py hook via the cache + its --self-test
#   6. Runs the lab grader in dry-run mode
#   7. Prints a clear PASS / FAIL summary
#
# Exit codes: 0 = all green, 1 = at least one failure
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
RESULTS=()

# ---- colours (disabled when not a terminal) --------------------------------
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; NC=''
fi

ok()   { PASS=$((PASS+1)); RESULTS+=("${GREEN}PASS${NC}  $1"); }
fail() { FAIL=$((FAIL+1)); RESULTS+=("${RED}FAIL${NC}  $1${2:+ -- $2}"); }
warn() { echo -e "${YELLOW}WARN${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ---- 1. Locate plugin -------------------------------------------------------
header "Plugin discovery"

PLUGIN_ROOT=""
for candidate in \
  "$HOME/.claude/plugins/cache/mastercard-workbench/workbench/"*/; do
  if [ -f "${candidate}hooks/hooks.json" ]; then
    PLUGIN_ROOT="${candidate%/}"
  fi
done

if [ -z "$PLUGIN_ROOT" ]; then
  fail "workbench plugin not found" "Run: claude plugin marketplace add https://github.com/ArulaAI/arula-mc-labs-plugin && claude plugin install workbench@mastercard-workbench"
  echo -e "\n${RED}Cannot continue without the plugin installed.${NC}"
  exit 1
fi
ok "Plugin found at $PLUGIN_ROOT"

# ---- 2. Plugin resolve-python ------------------------------------------------
header "Python resolver (plugin)"

CACHE_FILE="$REPO_ROOT/.claude/hooks/.python_path"
RESOLVE_SCRIPT="$PLUGIN_ROOT/hooks/resolve-python"

# Remove stale cache so we test a fresh resolution
rm -f "$CACHE_FILE"

if [ -f "$RESOLVE_SCRIPT" ]; then
  if output=$(CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "$RESOLVE_SCRIPT" 2>&1); then
    ok "resolve-python ran successfully"
    echo "  $output"
  else
    fail "resolve-python failed" "$output"
    echo -e "\n${RED}Cannot continue without Python. Fix this first.${NC}"
    exit 1
  fi
else
  fail "resolve-python not found at $RESOLVE_SCRIPT" "Plugin may need updating"
  echo -e "\n${RED}Plugin is missing resolve-python script. Update the plugin.${NC}"
  exit 1
fi

# Verify the cache file was created and is usable
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  PY=$(cat "$CACHE_FILE")
  if "$PY" -c "pass" 2>/dev/null; then
    ok "Cache file created and Python path valid: $PY"
  else
    fail "Cache file exists but Python path is invalid" "$PY"
    exit 1
  fi
else
  fail "Cache file not created at $CACHE_FILE"
  exit 1
fi

PY_VERSION="$("$PY" -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")"
echo "  Python version: $PY_VERSION"

# ---- 3. Check pyyaml -------------------------------------------------------
header "Python dependencies"

if "$PY" -c "import yaml" 2>/dev/null; then
  ok "pyyaml importable"
else
  fail "pyyaml not installed" "Run: $PY -m pip install pyyaml"
fi

# ---- 4. Plugin hooks via run-python -----------------------------------------
header "Plugin hooks (via run-python)"

RUN_SCRIPT="$PLUGIN_ROOT/hooks/run-python"

if [ ! -f "$RUN_SCRIPT" ]; then
  fail "run-python not found at $RUN_SCRIPT" "Plugin may need updating"
else
  # Helper: run a hook via the plugin's run-python script
  run_hook() {
    local label="$1" script="$2" event="$3" payload="$4"
    local output
    if output=$(echo "$payload" | \
      CLAUDE_PROJECT_DIR="$REPO_ROOT" \
      WORKBENCH_JOURNEY_DIR=".claude/journey" \
      CLAUDE_SESSION_ID="verify-hooks-test" \
      CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
      bash "$RUN_SCRIPT" "$script" "$event" 2>&1); then
      ok "$label"
    else
      fail "$label" "$output"
    fi
  }

  JOURNEY_HOOK="$PLUGIN_ROOT/hooks/journey_record.py"
  QUALITY_HOOK="$PLUGIN_ROOT/hooks/quality_gates.py"
  SAMPLE_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"echo hello"},"session_id":"verify-hooks-test"}'

  # SessionStart
  run_hook "journey_record.py  session-start" "$JOURNEY_HOOK" "session-start" "$SAMPLE_PAYLOAD"

  # PreToolUse - journey
  run_hook "journey_record.py  pre-tool"      "$JOURNEY_HOOK" "pre-tool"      "$SAMPLE_PAYLOAD"

  # PreToolUse - quality gates
  run_hook "quality_gates.py   pre-tool"      "$QUALITY_HOOK" "pre-tool"      "$SAMPLE_PAYLOAD"

  # PostToolUse - journey
  run_hook "journey_record.py  post-tool"     "$JOURNEY_HOOK" "post-tool"     "$SAMPLE_PAYLOAD"

  # Stop
  run_hook "journey_record.py  stop"          "$JOURNEY_HOOK" "stop"          "$SAMPLE_PAYLOAD"

  # Verify a journey file was actually written
  VERIFY_JOURNEY="$REPO_ROOT/.claude/journey/verify-hooks-test.jsonl"
  if [ -f "$VERIFY_JOURNEY" ]; then
    LINE_COUNT=$(wc -l < "$VERIFY_JOURNEY")
    ok "Journey file written ($LINE_COUNT events in verify-hooks-test.jsonl)"
    # Clean up the test journey file
    rm -f "$VERIFY_JOURNEY"
  else
    fail "Journey file not created" "Expected $VERIFY_JOURNEY"
  fi
fi

# ---- 5. Repo-local gate_guard.py (via cache) --------------------------------
header "Repo-local hooks (gate_guard via cache)"

GATE_GUARD="$REPO_ROOT/.claude/hooks/gate_guard.py"
if [ -f "$GATE_GUARD" ]; then
  # Read the cached Python path (same way the lab's settings.json does)
  CACHED_PY="$(cat "$CACHE_FILE")"

  # Basic invocation (should allow a non-write tool)
  ALLOW_PAYLOAD='{"tool_name":"Read","tool_input":{"file_path":"reference/README.md"}}'
  if echo "$ALLOW_PAYLOAD" | CLAUDE_PROJECT_DIR="$REPO_ROOT" "$CACHED_PY" "$GATE_GUARD" 2>/dev/null; then
    ok "gate_guard.py allows Read on gated path (correct)"
  else
    fail "gate_guard.py blocked a Read (should allow)"
  fi

  # Should block a Write to reference/
  BLOCK_PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"reference/RefundService.solved.java"}}'
  if echo "$BLOCK_PAYLOAD" | CLAUDE_PROJECT_DIR="$REPO_ROOT" "$CACHED_PY" "$GATE_GUARD" 2>/dev/null; then
    fail "gate_guard.py allowed Write to reference/ (should block)"
  else
    ok "gate_guard.py blocks Write to reference/ (correct)"
  fi

  # Full self-test (covers all 4 bypass classes + controls)
  if CLAUDE_PROJECT_DIR="$REPO_ROOT" "$CACHED_PY" "$GATE_GUARD" --self-test 2>&1 | tail -1 | grep -q "0 failed"; then
    ok "gate_guard.py --self-test all cases pass"
  else
    fail "gate_guard.py --self-test had failures" "Run: $CACHED_PY $GATE_GUARD --self-test"
  fi
else
  fail "gate_guard.py not found at $GATE_GUARD"
fi

# ---- 6. Lab grader (dry run) -----------------------------------------------
header "Lab grader"

GRADER="$REPO_ROOT/.claude/scripts/grade_repo.py"
if [ -f "$GRADER" ]; then
  if GRADER_OUTPUT=$("$PY" "$GRADER" 2>&1); then
    ok "grade_repo.py runs without errors"
    # Extract score line
    SCORE_LINE=$(echo "$GRADER_OUTPUT" | grep -i "score\|total" | tail -1)
    if [ -n "$SCORE_LINE" ]; then
      echo "  $SCORE_LINE"
    fi
  else
    # Grader returning nonzero is fine (lab not done yet), but a Python crash is not
    if echo "$GRADER_OUTPUT" | grep -qi "traceback\|error\|ModuleNotFoundError"; then
      fail "grade_repo.py crashed" "$(echo "$GRADER_OUTPUT" | tail -3)"
    else
      ok "grade_repo.py runs (score below pass threshold -- expected for a fresh lab)"
      SCORE_LINE=$(echo "$GRADER_OUTPUT" | grep -i "score\|total" | tail -1)
      if [ -n "$SCORE_LINE" ]; then
        echo "  $SCORE_LINE"
      fi
    fi
  fi
else
  fail "grade_repo.py not found at $GRADER"
fi

# ---- Cleanup ----------------------------------------------------------------
rm -f "$CACHE_FILE"

# ---- Summary ---------------------------------------------------------------
header "Results"

for r in "${RESULTS[@]}"; do
  echo -e "  $r"
done

echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}ALL $TOTAL CHECKS PASSED${NC} -- hooks are ready for the lab session."
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL of $TOTAL CHECKS FAILED${NC} -- fix the issues above before the session."
  exit 1
fi
