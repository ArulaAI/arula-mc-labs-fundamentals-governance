#!/usr/bin/env bash
# json.sh — minimal, dependency-free JSON reading for hook payloads.
#
# Claude Code delivers hook input as a JSON object on stdin (NOT via environment
# variables). We cannot assume jq, python, or node are installed: the lab's stated
# prerequisites are Java + Maven and "no other tooling". So this is hand-rolled
# against the known, documented hook payload shape rather than being a general
# JSON parser.
#
# Scope of what this handles, deliberately:
#   - top-level string values          "session_id": "abc123"
#   - top-level scalar (num/bool/null) "exit_code": 0
#   - nested objects are NOT walked; use json_raw_slice for a preview instead.
#
# Anything more structured than that belongs in the payload preview, which is
# redacted and truncated anyway.

# json_str <json> <key>
# Echoes the string value for <key>, with JSON escapes decoded. Empty if absent.
json_str() {
    local json="$1" key="$2" raw
    raw=$(printf '%s' "$json" \
        | tr -d '\n' \
        | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' \
        | head -n 1)
    [ -z "$raw" ] && return 0
    # Decode the escapes that actually occur in hook payloads.
    printf '%s' "$raw" \
        | sed -e 's/\\"/"/g' \
              -e 's/\\n/ /g' \
              -e 's/\\r/ /g' \
              -e 's/\\t/ /g' \
              -e 's/\\\\/\\/g'
}

# json_scalar <json> <key>
# Echoes an unquoted scalar (number, true/false, null). Empty if absent.
json_scalar() {
    printf '%s' "$1" \
        | tr -d '\n' \
        | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([-0-9.eE+]\{1,\}\|true\|false\|null\).*/\1/p' \
        | head -n 1
}

# json_raw_slice <json> <key> <max_chars>
# Echoes the raw text following "<key>": — object, array, or string alike —
# truncated to <max_chars>. Used to build a payload preview without needing to
# understand the payload's internal shape.
json_raw_slice() {
    local json="$1" key="$2" max="${3:-400}"
    printf '%s' "$json" \
        | tr '\n' ' ' \
        | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\(.*\)/\1/p' \
        | head -n 1 \
        | cut -c "1-${max}"
}

# json_escape <text>
# Escapes text for safe embedding as a JSON string value.
json_escape() {
    printf '%s' "$1" \
        | sed -e 's/\\/\\\\/g' \
              -e 's/"/\\"/g' \
              -e 's/\t/ /g' \
        | tr -d '\r' \
        | tr '\n' ' '
}
