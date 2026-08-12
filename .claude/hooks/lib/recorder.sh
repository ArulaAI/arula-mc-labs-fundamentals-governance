#!/usr/bin/env bash
# recorder.sh — appends one structured JSON event to the journey log.
#
# Usage: recorder.sh <lab_root> <run_id> <event_json_no_braces>
#
# Journey file: <lab_root>/.claude/journey/<run_id>.jsonl (append-only, one
# event per line). run_id is the harness-supplied session_id — no local
# UUID generation needed (Claude Code already gives us a stable session id
# per stdin payload; see hooks-reference.md, "session_id").
#
# Non-fatal by design: a recording failure must never block the participant's
# actual work. Callers should invoke this with `|| true`.

set -euo pipefail

LAB_ROOT="${1:?lab_root required}"
RUN_ID="${2:?run_id required}"
EVENT_FRAGMENT="${3:?event json fragment required}"

JOURNEY_DIR="$LAB_ROOT/.claude/journey"
JOURNEY_FILE="$JOURNEY_DIR/${RUN_ID}.jsonl"

mkdir -p "$JOURNEY_DIR"

EVENT_SEQ_FILE="$JOURNEY_DIR/.${RUN_ID}.seq"
SEQ=0
[ -f "$EVENT_SEQ_FILE" ] && SEQ=$(cat "$EVENT_SEQ_FILE" 2>/dev/null || echo 0)
SEQ=$((SEQ + 1))
printf '%s' "$SEQ" > "$EVENT_SEQ_FILE"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Compose the full line. EVENT_FRAGMENT is the caller's field set with no
# surrounding braces, e.g.  "type":"pre_tool_use","tool_name":"Bash"
printf '{"seq":%d,"ts":"%s","run_id":"%s","harness":"claude-code",%s}\n' \
    "$SEQ" "$TS" "$RUN_ID" "$EVENT_FRAGMENT" >> "$JOURNEY_FILE"
