#!/usr/bin/env bash
# quality-gates.sh — PostToolUse hook (matcher: "Bash"). Fires after every Bash
# call, cheaply exits unless the command was a Maven verify/test run, then runs
# 4 gates against the working tree and prints a summary.
#
# Design decisions, stated explicitly:
#
#   - NON-BLOCKING BY DESIGN. This hook always exits 0. It reports findings to
#     stdout/stderr and to the journey log; it does not attempt to block the
#     agent loop (a Claude Code hook technically can, via exit code / JSON
#     response, but a heuristic bash scanner with no network access and no
#     real AST will have false positives, and this is a training lab, not a
#     production gate — a false block would be worse than a visible warning).
#     Stage 6 of the lab explicitly reviews gate output as part of governance
#     review; the human is the actual gate.
#
#   - Config is read from an OPTIONAL .claude/quality-gates.json in the lab
#     repo for overrides, with safe generic defaults baked in in bash.
#
#   - Gate 4 (unknown dependency) cannot truly confirm a Maven coordinate is
#     "real" without network access (this lab is offline by design). What it
#     CAN do: diff pom.xml's <dependency> blocks against a locked baseline
#     snapshot taken the first time it runs in this repo, and flag any new
#     coordinate as requiring explicit human confirmation. This is the
#     honest version of "unknown-dependency check" under a no-network
#     constraint — it surfaces the fake com.mastercard:pan-vault addition
#     (the lab's seeded FM1 trap) but it is a diff-based heuristic, not a
#     registry lookup. Documented limitation, not a silent gap.
#
# This repo commits the hook directly (no plugin-install indirection), so it
# is always active once wired in .claude/settings.json — no separate opt-in.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json.sh"
source "$SCRIPT_DIR/lib/redact.sh"

LAB_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PAYLOAD="$(cat)"
[ -z "$PAYLOAD" ] && exit 0

CMD="$(json_str "$PAYLOAD" "command")"
case "$CMD" in
    *mvn*verify*|*mvn*test*) : ;;
    *) exit 0 ;;
esac

CONFIG="$LAB_ROOT/.claude/quality-gates.json"
COVERAGE_THRESHOLD=0   # 0 = report only, don't gate on a number unless configured
if [ -f "$CONFIG" ]; then
    cfg_json="$(cat "$CONFIG")"
    cfg_threshold="$(json_scalar "$cfg_json" "coverage_threshold_percent")"
    [ -n "$cfg_threshold" ] && COVERAGE_THRESHOLD="$cfg_threshold"
fi

FINDINGS=()
add_finding() { FINDINGS+=("$1"); }

# ---------------------------------------------------------------------------
# Gate 1 — cardholder-data scan
# Scans build/test artifacts actually produced by the mvn run just executed:
# logs and audit files under target/, and Surefire's captured stdout/stderr,
# for PAN-shaped digit runs (13-19 digits) or a literal CVV mention outside
# of source comments. This is the static-artifact equivalent of "no PAN/CVV
# in logs or responses" — it cannot inspect a live HTTP response body, but
# every response-body leak in this lab's seeded findings is also written to
# target/auth-audit.log, so the log scan catches it.
# ---------------------------------------------------------------------------
gate_cardholder_data() {
    local hit_files=()
    local scan_paths=(
        "$LAB_ROOT/target/auth-audit.log"
        "$LAB_ROOT/target/surefire-reports"
    )
    for p in "${scan_paths[@]}"; do
        [ -e "$p" ] || continue
        while IFS= read -r -d '' f; do
            if grep -qE '[0-9]{13,19}' "$f" 2>/dev/null || grep -qiE '\bcvv\b[[:space:]]*[:=][[:space:]]*[0-9]' "$f" 2>/dev/null; then
                hit_files+=("${f#$LAB_ROOT/}")
            fi
        done < <(find "$p" -type f -print0 2>/dev/null)
    done
    if [ "${#hit_files[@]}" -gt 0 ]; then
        add_finding "FAIL cardholder-data: PAN/CVV-shaped data found in: ${hit_files[*]}"
    else
        add_finding "PASS cardholder-data: no PAN/CVV-shaped data in scanned build artifacts"
    fi
}

# ---------------------------------------------------------------------------
# Gate 2 — secret scan
# Generic patterns over tracked source/config files (not target/, not .git/).
# ---------------------------------------------------------------------------
gate_secret_scan() {
    local hits
    hits=$(cd "$LAB_ROOT" && git ls-files -- '*.java' '*.yml' '*.yaml' '*.properties' '*.xml' 2>/dev/null \
        | xargs -r grep -lEi \
            -e 'AKIA[0-9A-Z]{16}' \
            -e '(password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_-]{8,}' \
            -e '-----BEGIN (RSA |EC )?PRIVATE KEY-----' \
            2>/dev/null || true)
    if [ -n "$hits" ]; then
        add_finding "WARN secret-scan: possible hardcoded secret pattern in: $(printf '%s' "$hits" | tr '\n' ' ')"
    else
        add_finding "PASS secret-scan: no obvious hardcoded-secret patterns found"
    fi
}

# ---------------------------------------------------------------------------
# Gate 3 — coverage threshold
# Reads JaCoCo's aggregate line-coverage percentage from target/site/jacoco/jacoco.xml
# if present. Report-only unless COVERAGE_THRESHOLD > 0.
# ---------------------------------------------------------------------------
gate_coverage() {
    local jacoco_xml="$LAB_ROOT/target/site/jacoco/jacoco.xml"
    if [ ! -f "$jacoco_xml" ]; then
        add_finding "SKIP coverage: target/site/jacoco/jacoco.xml not found (run 'mvn verify' with the jacoco:report goal bound)"
        return
    fi
    # JaCoCo's report-level LINE counter: <counter type="LINE" missed="X" covered="Y"/>
    # is the LAST such counter in the file (module-level, after per-package ones).
    local line
    line=$(grep -o '<counter type="LINE" missed="[0-9]*" covered="[0-9]*"/>' "$jacoco_xml" | tail -n 1)
    if [ -z "$line" ]; then
        add_finding "SKIP coverage: no LINE counter found in jacoco.xml"
        return
    fi
    local missed covered pct
    missed=$(printf '%s' "$line" | sed -n 's/.*missed="\([0-9]*\)".*/\1/p')
    covered=$(printf '%s' "$line" | sed -n 's/.*covered="\([0-9]*\)".*/\1/p')
    if [ "$((missed + covered))" -eq 0 ]; then
        add_finding "SKIP coverage: zero total lines counted"
        return
    fi
    pct=$(( covered * 100 / (missed + covered) ))
    if [ "$COVERAGE_THRESHOLD" -gt 0 ] && [ "$pct" -lt "$COVERAGE_THRESHOLD" ]; then
        add_finding "FAIL coverage: ${pct}% line coverage, below configured threshold ${COVERAGE_THRESHOLD}%"
    else
        add_finding "PASS coverage: ${pct}% line coverage (covered=${covered}, missed=${missed})"
    fi
}

# ---------------------------------------------------------------------------
# Gate 4 — unknown dependency (diff-based, see header note on network limits)
# ---------------------------------------------------------------------------
gate_unknown_dependency() {
    local pom="$LAB_ROOT/pom.xml"
    [ -f "$pom" ] || { add_finding "SKIP unknown-dependency: no pom.xml"; return; }

    local baseline="$LAB_ROOT/.claude/.pom-dependency-baseline.txt"
    mkdir -p "$LAB_ROOT/.claude"

    # Extract "groupId:artifactId" per <dependency> block, tolerant of formatting.
    local current
    # NOTE: gsub() with no 3rd arg mutates $0 in place, which corrupts later
    # pattern tests against the SAME line (e.g. a one-line <dependency>...
    # </dependency> block) since /<artifactId>/ and /<\/dependency>/ would
    # then be matched against the already-stripped text. Always gsub into a
    # local copy instead.
    current=$(awk '
        /<dependency>/{ g=""; a=""; in_dep=1 }
        in_dep && /<groupId>/{ line=$0; gsub(/.*<groupId>|<\/groupId>.*/,"",line); g=line }
        in_dep && /<artifactId>/{ line=$0; gsub(/.*<artifactId>|<\/artifactId>.*/,"",line); a=line }
        /<\/dependency>/{ if (g!="" && a!="") print g":"a; in_dep=0 }
    ' "$pom" | sort -u)

    if [ ! -f "$baseline" ]; then
        printf '%s\n' "$current" > "$baseline"
        add_finding "PASS unknown-dependency: baseline recorded (.claude/.pom-dependency-baseline.txt) — nothing to compare yet"
        return
    fi

    local new_deps
    new_deps=$(comm -13 "$baseline" <(printf '%s\n' "$current") 2>/dev/null || true)
    if [ -n "$new_deps" ]; then
        add_finding "WARN unknown-dependency: new pom.xml coordinate(s) not in baseline, requires manual confirmation (no network access to verify against a registry): $(printf '%s' "$new_deps" | tr '\n' ' ')"
    else
        add_finding "PASS unknown-dependency: no new pom.xml coordinates since baseline"
    fi
}

gate_cardholder_data
gate_secret_scan
gate_coverage
gate_unknown_dependency

SUMMARY="quality_gates: $(printf '%s | ' "${FINDINGS[@]}")"
echo "$SUMMARY" >&2

RUN_ID="$(json_str "$PAYLOAD" "session_id")"
[ -z "$RUN_ID" ] && RUN_ID="unknown_session"

# Structured, un-truncated artifact for downstream consumers (lab-grader).
# The journey log below gets a redacted/truncated PREVIEW of this same summary
# (correct for an audit trail of possibly-sensitive text), but a grader needs
# reliable status-per-gate, not an 80-char preview that may cut a gate off
# mid-sentence. Gate summary text here is our own generated status lines
# (PASS/FAIL/WARN/SKIP + gate name + short reason) — never raw cardholder
# data — so writing it in full to this artifact is safe.
GATES_JSON_PATH="$LAB_ROOT/.claude/quality-gates-latest.json"
{
    printf '{"run_id":"%s","ts":"%s","gates":{' "$(json_escape "$RUN_ID")" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    first=1
    for f in "${FINDINGS[@]}"; do
        status="${f%% *}"
        rest="${f#* }"
        gate_name="${rest%%:*}"
        [ "$first" -eq 1 ] || printf ','
        printf '"%s":"%s"' "$(json_escape "$gate_name")" "$(json_escape "$status")"
        first=0
    done
    printf '}}\n'
} > "$GATES_JSON_PATH"

FRAGMENT="\"type\":\"quality_gates_run\",$(redact_field "summary" "$SUMMARY")"
bash "$SCRIPT_DIR/lib/recorder.sh" "$LAB_ROOT" "$RUN_ID" "$FRAGMENT" 2>/dev/null || true

exit 0
