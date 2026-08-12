#!/usr/bin/env bash
# test_journey_record_hook.sh — regression test: an earlier donor hook design
# read nonexistent env vars ($CLAUDE_TOOL_NAME etc.) and would have recorded
# empty payloads for every event. This test asserts journey-record.sh actually
# captures real content from the documented stdin-JSON hook payload shape.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/journey-record.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q

pass=0
fail=0
check() {
    if [ "$1" = "$2" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $3 — expected [$2], got [$1]" >&2
    fi
}

# --- pre_tool_use: assert tool_name and a non-empty args hash were captured ---
echo '{"session_id":"sess_1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"mvn test"},"tool_use_id":"t1"}' \
    | bash "$HOOK" pre_tool_use

LINE1="$(tail -n 1 .claude/journey/sess_1.jsonl)"
echo "$LINE1" | grep -q '"type":"pre_tool_use"' && check ok ok "pre_tool_use type recorded" || check missing ok "pre_tool_use type recorded"
echo "$LINE1" | grep -q '"tool_name":"Bash"' && check ok ok "tool_name captured (regression: donor read \$CLAUDE_TOOL_NAME which does not exist)" || check missing ok "tool_name captured"
echo "$LINE1" | grep -qE '"args_hash":"[0-9a-f]{16}"' && check ok ok "args_hash is a real 16-hex-char hash, not empty" || check missing ok "args_hash is a real 16-hex-char hash"
echo "$LINE1" | grep -q '"args_len":0' && check found_zero_len should_be_nonzero "args payload was NOT empty (the actual regression)" || check ok ok "args payload was NOT empty (the actual regression)"

# --- post_tool_use: assert PAN and bearer token in output get redacted, not stored raw ---
echo '{"session_id":"sess_1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"mvn test"},"tool_result":{"output":"card 4111111111111111 approved, Bearer eyJhbGciOiJIUzI1NiJ9.abc.def","exit_code":0}}' \
    | bash "$HOOK" post_tool_use

LINE2="$(tail -n 1 .claude/journey/sess_1.jsonl)"
echo "$LINE2" | grep -q '4111111111111111' && check found_raw_pan should_be_redacted "raw PAN must NOT appear in journey log" || check ok ok "raw PAN must NOT appear in journey log"
echo "$LINE2" | grep -q 'eyJhbGciOiJIUzI1NiJ9' && check found_raw_token should_be_redacted "raw bearer token must NOT appear in journey log" || check ok ok "raw bearer token must NOT appear in journey log"
echo "$LINE2" | grep -q 'REDACTED-PAN' && check ok ok "PAN redaction marker present in preview" || check missing ok "PAN redaction marker present in preview"
echo "$LINE2" | grep -q '"exit_code":0' && check ok ok "exit_code captured" || check missing ok "exit_code captured"

# --- always-active: this repo commits its hooks directly (no plugin opt-in
# gate), so a bare repo with no special config file must still record. This
# replaces the old plugin-model "opt-out gate" test, which no longer applies. ---
TMP2="$(mktemp -d)"
(cd "$TMP2" && git init -q && echo '{"session_id":"sess_2","hook_event_name":"SessionStart","session_type":"startup"}' | bash "$HOOK" session_start)
if [ -f "$TMP2/.claude/journey/sess_2.jsonl" ]; then
    check ok ok "hooks record without any special opt-in file present"
else
    check missing ok "hooks record without any special opt-in file present"
fi
rm -rf "$TMP2"

echo "journey_record hook tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
