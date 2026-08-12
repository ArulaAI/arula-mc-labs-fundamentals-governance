#!/usr/bin/env bash
# journey-record.sh — Claude Code hook entry point for journey recording.
#
# Invoked by .claude/settings.json on 7 lifecycle events. Claude Code delivers
# the event payload as JSON on STDIN — this script does NOT read
# $CLAUDE_TOOL_NAME / $CLAUDE_TOOL_INPUT / $CLAUDE_USER_PROMPT env vars,
# because those do not exist in the current hook contract.
#
# Usage (from settings.json): journey-record.sh <event_type>
#   event_type is one of: pre_tool_use, post_tool_use, user_prompt_submit,
#                          session_start, session_end, subagent_start, subagent_stop
#
# This repo commits these hooks directly (no plugin-install indirection), so
# unlike an installable-plugin version there is no separate per-repo opt-in
# gate — if the hook is wired in .claude/settings.json, it is active.
#
# Non-fatal: any failure here must never block or slow the participant's
# actual work, so every failure path exits 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/json.sh
source "$SCRIPT_DIR/lib/json.sh"
# shellcheck source=lib/redact.sh
source "$SCRIPT_DIR/lib/redact.sh"

EVENT_TYPE="${1:-unknown}"

LAB_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PAYLOAD="$(cat)"
[ -z "$PAYLOAD" ] && exit 0

SESSION_ID="$(json_str "$PAYLOAD" "session_id")"
[ -z "$SESSION_ID" ] && SESSION_ID="unknown_session"

FRAGMENT="\"type\":\"$(json_escape "$EVENT_TYPE")\""

case "$EVENT_TYPE" in
    pre_tool_use)
        TOOL_NAME="$(json_str "$PAYLOAD" "tool_name")"
        TOOL_INPUT_RAW="$(json_raw_slice "$PAYLOAD" "tool_input" 500)"
        FRAGMENT="$FRAGMENT,\"tool_name\":\"$(json_escape "$TOOL_NAME")\",$(redact_field "args" "$TOOL_INPUT_RAW")"
        ;;
    post_tool_use)
        TOOL_NAME="$(json_str "$PAYLOAD" "tool_name")"
        OUTPUT_RAW="$(json_raw_slice "$PAYLOAD" "output" 800)"
        EXIT_CODE="$(json_scalar "$PAYLOAD" "exit_code")"
        [ -z "$EXIT_CODE" ] && EXIT_CODE="null"
        FRAGMENT="$FRAGMENT,\"tool_name\":\"$(json_escape "$TOOL_NAME")\",\"exit_code\":${EXIT_CODE},$(redact_field "result" "$OUTPUT_RAW")"
        ;;
    user_prompt_submit)
        PROMPT="$(json_str "$PAYLOAD" "user_input")"
        FRAGMENT="$FRAGMENT,$(redact_field "prompt" "$PROMPT")"
        ;;
    session_start)
        SESSION_TYPE="$(json_str "$PAYLOAD" "session_type")"
        FRAGMENT="$FRAGMENT,\"session_type\":\"$(json_escape "$SESSION_TYPE")\""
        ;;
    session_end)
        END_REASON="$(json_str "$PAYLOAD" "end_reason")"
        FRAGMENT="$FRAGMENT,\"end_reason\":\"$(json_escape "$END_REASON")\""
        ;;
    subagent_start|subagent_stop)
        # NOTE: the exact stdin field name for "which subagent" was not
        # confirmed against live payload docs at build time (only
        # PreToolUse/PostToolUse/UserPromptSubmit/SessionStart/SessionEnd
        # schemas were available). We defensively try the two most likely
        # field names; this should be verified against a real captured
        # payload before grading depends on it.
        AGENT_TYPE="$(json_str "$PAYLOAD" "agent_type")"
        [ -z "$AGENT_TYPE" ] && AGENT_TYPE="$(json_str "$PAYLOAD" "subagent_type")"
        FRAGMENT="$FRAGMENT,\"agent_type\":\"$(json_escape "$AGENT_TYPE")\""
        ;;
    *)
        : # unknown event type — still record the bare envelope
        ;;
esac

bash "$SCRIPT_DIR/lib/recorder.sh" "$LAB_ROOT" "$SESSION_ID" "$FRAGMENT" 2>/dev/null || true

exit 0
