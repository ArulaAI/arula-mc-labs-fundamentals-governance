#!/usr/bin/env bash
# test_rubric.sh — validates .claude/rubrics/finish-the-refund.rubric.yaml's own structure and
# content, independent of whether the workbench plugin is installed on this machine (the
# grading ENGINE, grader.py, is plugin-owned and tested there -- this repo only owns the
# rubric's content, so that's what this test scopes to).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUBRIC="$REPO_ROOT/.claude/rubrics/finish-the-refund.rubric.yaml"

pass=0
fail=0
check() { if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not available -- rubric content not validated" >&2
    exit 0
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
    echo "SKIP: pyyaml not installed (a documented plugin prerequisite) -- rubric content not validated" >&2
    exit 0
fi

python3 <<PYEOF
import re
import sys
import yaml

rubric = yaml.safe_load(open("$RUBRIC"))
pass_count = 0
fail_count = 0

def check(ok, msg):
    global pass_count, fail_count
    if ok:
        pass_count += 1
    else:
        fail_count += 1
        print(f"FAIL: {msg}", file=sys.stderr)

check(rubric.get("lab") == 1, "lab: 1")
check(isinstance(rubric.get("pass_threshold"), (int, float)), "pass_threshold is numeric")
criteria = rubric.get("criteria", [])
check(len(criteria) > 0, "at least one criterion")

# Every criterion's check string must use a prefix grader.py actually implements.
known_prefixes = (
    "event_exists:", "event_contains:", "event_count_gte:", "secret_scan_clean",
    "file_contains:", "file_contains_all:", "file_secret_scan_clean:",
    "file_row_contains_all:", "file_table_rows_gte:",
)
ids_seen = set()
for c in criteria:
    cid = c.get("id", "<missing id>")
    check(cid not in ids_seen, f"criterion id '{cid}' is unique")
    ids_seen.add(cid)
    check(isinstance(c.get("max_score"), (int, float)) and c["max_score"] >= 0, f"'{cid}' has a non-negative max_score")
    chk = c.get("check", "")
    check(chk.startswith(known_prefixes), f"'{cid}' check '{chk}' uses a known grader.py check type")

# Every finding F1-F10 must be referenced somewhere in the rubric (registered, fixed, or backlog).
rubric_text = open("$RUBRIC").read()
for i in range(1, 11):
    check(re.search(rf"\bF{i}\b", rubric_text) is not None, f"F{i} referenced somewhere in the rubric")

# F5 and the two Stage-4 fixes must be more than a bare existence check.
f5_criteria = [c for c in criteria if "f5" in c.get("id", "").lower()]
check(any("escalat" in c.get("check", "") for c in f5_criteria), "F5 criterion checks for an escalation note, not just presence")

print(f"rubric content tests: {pass_count} passed, {fail_count} failed")
sys.exit(1 if fail_count else 0)
PYEOF
