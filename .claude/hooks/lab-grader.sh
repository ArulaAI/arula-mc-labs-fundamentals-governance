#!/usr/bin/env bash
# lab-grader.sh — deterministic rubric evaluator. Pure bash (no python/jq — lab
# prereqs are Java + Maven only). Parses a constrained YAML subset (see the
# format note below) rather than being a general YAML parser.
#
# Usage:
#   lab-grader.sh [lab_root] [--rubric PATH] [--run-id ID] [--format json|markdown|both]
#
# Exit code: 0 if grading completed (regardless of score), 1 on a rubric
# parse error or missing rubric file — a low score is a valid result; a
# broken rubric is not.

set -uo pipefail

LAB_ROOT="."
RUBRIC=""
RUN_ID=""
FORMAT="both"

while [ $# -gt 0 ]; do
    case "$1" in
        --rubric) RUBRIC="$2"; shift 2 ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: lab-grader.sh [lab_root] [--rubric PATH] [--run-id ID] [--format json|markdown|both]"
            exit 0
            ;;
        *) LAB_ROOT="$1"; shift ;;
    esac
done

if [ ! -d "$LAB_ROOT" ]; then
    echo "grader: lab_root not found: $LAB_ROOT" >&2
    exit 1
fi
LAB_ROOT="$(cd "$LAB_ROOT" && pwd)"

[ -z "$RUBRIC" ] && RUBRIC="$LAB_ROOT/.claude/fundamentals.rubric.yaml"
if [ ! -f "$RUBRIC" ]; then
    echo "grader: rubric not found at $RUBRIC" >&2
    exit 1
fi

if [ -z "$RUN_ID" ]; then
    latest="$(ls -t "$LAB_ROOT"/.claude/journey/*.jsonl 2>/dev/null | head -n 1 || true)"
    if [ -n "$latest" ]; then
        RUN_ID="$(basename "$latest" .jsonl)"
    else
        RUN_ID="run_unknown"
    fi
fi
JOURNEY_FILE="$LAB_ROOT/.claude/journey/${RUN_ID}.jsonl"
GATES_JSON="$LAB_ROOT/.claude/quality-gates-latest.json"

# ---------------------------------------------------------------------------
# Rubric format (strict subset, not general YAML):
#
#   - id: <slug>
#     title: <text>
#     weight: <int>
#     check: file_exists | file_contains | min_line_count | pattern_count | quality_gate_pass | journey_event_count | shell
#     path: <relative path>            (file_exists, file_contains, min_line_count, pattern_count)
#     pattern: <grep -E pattern>       (file_contains, pattern_count)
#     min_lines: <int>                 (min_line_count)
#     min_count: <int>                 (pattern_count, journey_event_count)
#     gate: <gate-name>                (quality_gate_pass — matches a key in quality-gates-latest.json)
#     event_type: <type>               (journey_event_count)
#     cmd: <shell command>             (shell — run from LAB_ROOT; no colon in the command,
#                                        since "key: value" parsing splits on the first ": ")
#     expect_exit: <int>               (shell — default 0)
#
# Each field is a "key: value" line indented under a "- id: ..." line. One
# criterion per block. No nested lists, no multi-line values, no anchors.
# ---------------------------------------------------------------------------

RS_SEP=$'\x1e'
FS_SEP=$'\x1f'

RECORDS="$(grep -vE '^[[:space:]]*(#|$)' "$RUBRIC" | awk -v FS_SEP="$FS_SEP" '
    function flush() { if (started) print rec }
    /^- / {
        flush()
        started = 1
        line = $0
        sub(/^- /, "", line)
        rec = line
        next
    }
    /^[[:space:]]+[A-Za-z_]+:/ {
        if (started) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            rec = rec FS_SEP line
        }
        next
    }
    END { flush() }
')"

if [ -z "$RECORDS" ]; then
    echo "grader: no criteria parsed from $RUBRIC — check rubric format" >&2
    exit 1
fi

# --- check implementations -------------------------------------------------

check_file_exists() {
    local path="$1"
    local target="$LAB_ROOT/$path"
    [ -s "$target" ] && return 0 || return 1
}

check_file_contains() {
    local path="$1" pattern="$2"
    local target="$LAB_ROOT/$path"
    if [ -d "$target" ]; then
        grep -rqE "$pattern" "$target" 2>/dev/null
    else
        [ -f "$target" ] && grep -qE "$pattern" "$target" 2>/dev/null
    fi
}

check_min_line_count() {
    local path="$1" min="$2"
    local target="$LAB_ROOT/$path" n
    [ -f "$target" ] || return 1
    n=$(wc -l < "$target" 2>/dev/null | tr -d ' ')
    [ -n "$n" ] && [ "$n" -ge "$min" ]
}

# check_pattern_count <path> <pattern> <min_count>
# Counts lines matching <pattern> (grep -E, one match per line) rather than
# just checking presence — use when "at least N occurrences" matters, e.g.
# "a '## Stage' header per stage" where a single file_contains would be
# satisfied by just one stage's entry.
check_pattern_count() {
    local path="$1" pattern="$2" min="$3"
    local target="$LAB_ROOT/$path" n
    [ -f "$target" ] || return 1
    # NOTE: `grep -c` prints "0" on zero matches but still exits 1 — a
    # `|| echo 0` fallback here would double-fire (grep's own "0" output
    # PLUS the fallback's), corrupting the later integer comparison with a
    # two-line "0\n0" string. Default via ${n:-0} instead, which only
    # substitutes on a genuinely empty/unset capture (e.g. a read error).
    n=$(grep -cE "$pattern" "$target" 2>/dev/null)
    n="${n:-0}"
    [ "$n" -ge "$min" ]
}

check_quality_gate_pass() {
    local gate="$1"
    [ -f "$GATES_JSON" ] || return 1
    # quality-gates-latest.json: {"gates":{"<gate>":"PASS"|"FAIL"|"WARN"|"SKIP",...}}
    local status
    status=$(sed -n 's/.*"'"$gate"'":"\([A-Z]*\)".*/\1/p' "$GATES_JSON" | head -n 1)
    [ "$status" = "PASS" ]
}

check_journey_event_count() {
    local event_type="$1" min_count="$2" n
    [ -f "$JOURNEY_FILE" ] || return 1
    # See check_pattern_count's note on why this isn't `|| echo 0`.
    n=$(grep -c "\"type\":\"$event_type\"" "$JOURNEY_FILE" 2>/dev/null)
    n="${n:-0}"
    [ "$n" -ge "$min_count" ]
}

# check_shell <cmd> <expect_exit>
# Runs <cmd> from LAB_ROOT and compares its exit code to <expect_exit> (default 0).
# This is the only check type that verifies actual runtime state (e.g. "does the test
# suite currently pass?") rather than static file/journey content — grading always
# happens after the fact, so this proves the CURRENT state, not a historical one (see
# fundamentals.rubric.yaml's comment on the Stage 3 checkpoint for that limitation).
check_shell() {
    local cmd="$1" expect="${2:-0}" rc
    ( cd "$LAB_ROOT" && eval "$cmd" ) >/dev/null 2>&1
    rc=$?
    [ "$rc" -eq "$expect" ]
}

# --- evaluate ----------------------------------------------------------------

TOTAL_WEIGHT=0
EARNED=0
RESULTS_JSON=""
RESULTS_MD=""
first=1

while IFS= read -r record; do
    [ -z "$record" ] && continue

    declare -A F=()
    IFS="$FS_SEP" read -ra fields <<< "$record"
    for field in "${fields[@]}"; do
        key="${field%%:*}"
        val="${field#*: }"
        key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        val="$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        F["$key"]="$val"
    done

    id="${F[id]:-unknown}"
    title="${F[title]:-$id}"
    weight="${F[weight]:-0}"
    check="${F[check]:-}"
    ok=false

    case "$check" in
        file_exists)
            check_file_exists "${F[path]:-}" && ok=true
            ;;
        file_contains)
            check_file_contains "${F[path]:-}" "${F[pattern]:-}" && ok=true
            ;;
        min_line_count)
            check_min_line_count "${F[path]:-}" "${F[min_lines]:-0}" && ok=true
            ;;
        pattern_count)
            check_pattern_count "${F[path]:-}" "${F[pattern]:-}" "${F[min_count]:-1}" && ok=true
            ;;
        quality_gate_pass)
            check_quality_gate_pass "${F[gate]:-}" && ok=true
            ;;
        journey_event_count)
            check_journey_event_count "${F[event_type]:-}" "${F[min_count]:-1}" && ok=true
            ;;
        shell)
            check_shell "${F[cmd]:-}" "${F[expect_exit]:-0}" && ok=true
            ;;
        *)
            echo "grader: unknown check type '$check' for criterion '$id' — treated as FAIL" >&2
            ok=false
            ;;
    esac

    points=0
    if [ "$ok" = true ]; then
        points="$weight"
        EARNED=$((EARNED + weight))
    fi
    TOTAL_WEIGHT=$((TOTAL_WEIGHT + weight))

    sep=","
    [ "$first" -eq 1 ] && sep=""
    RESULTS_JSON="${RESULTS_JSON}${sep}{\"id\":\"$(printf '%s' "$id" | sed 's/"/\\"/g')\",\"title\":\"$(printf '%s' "$title" | sed 's/"/\\"/g')\",\"weight\":$weight,\"passed\":$ok,\"points_earned\":$points}"
    RESULTS_MD="${RESULTS_MD}$( [ "$ok" = true ] && echo "[x]" || echo "[ ]" ) **${title}** (${points}/${weight})\n"
    first=0

    unset F
done <<< "$RECORDS"

PCT=0
[ "$TOTAL_WEIGHT" -gt 0 ] && PCT=$(( EARNED * 100 / TOTAL_WEIGHT ))

JOURNEY_DIR="$LAB_ROOT/.claude/journey"
mkdir -p "$JOURNEY_DIR"
GRADE_JSON_PATH="$JOURNEY_DIR/${RUN_ID}.grade.json"
GRADE_JSON="{\"run_id\":\"$(printf '%s' "$RUN_ID" | sed 's/"/\\"/g')\",\"total_score\":$EARNED,\"max_score\":$TOTAL_WEIGHT,\"percentage\":$PCT,\"criteria_results\":[$RESULTS_JSON]}"
printf '%s\n' "$GRADE_JSON" > "$GRADE_JSON_PATH"

if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "both" ]; then
    printf '%s\n' "$GRADE_JSON"
fi
if [ "$FORMAT" = "markdown" ] || [ "$FORMAT" = "both" ]; then
    printf '\n## Grade: %d / %d (%d%%)\n\n' "$EARNED" "$TOTAL_WEIGHT" "$PCT"
    printf '%b' "$RESULTS_MD"
fi

exit 0
