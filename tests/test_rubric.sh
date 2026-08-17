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
    "file_table_row_contains_all:", "file_contains_all_uncommented:",
    "file_sections_nonempty:",
    # Lab-local additions, implemented in .claude/scripts/grade_repo.py:
    #   all_of:      composes several checks; every sub-check must pass
    #   seed_intact: a seeded finding's code is byte-for-byte unmodified (F5)
    "all_of:", "seed_intact:",
)
ids_seen = set()
for c in criteria:
    cid = c.get("id", "<missing id>")
    check(cid not in ids_seen, f"criterion id '{cid}' is unique")
    ids_seen.add(cid)
    check(isinstance(c.get("max_score"), (int, float)) and c["max_score"] >= 0, f"'{cid}' has a non-negative max_score")
    chk = c.get("check", "")
    check(chk.startswith(known_prefixes), f"'{cid}' check '{chk}' uses a known grader.py check type")

# Every finding F1-F14 must be referenced somewhere in the rubric (registered, fixed, or backlog).
rubric_text = open("$RUBRIC").read()
for i in range(1, 15):
    check(re.search(rf"\bF{i}\b", rubric_text) is not None, f"F{i} referenced somewhere in the rubric")

# F5 and the two Stage-4 fixes must be more than a bare existence check.
f5_criteria = [c for c in criteria if "f5" in c.get("id", "").lower()]
check(any("escalat" in c.get("check", "") for c in f5_criteria), "F5 criterion checks for an escalation note, not just presence")
# ...and more than a register-row check: it must also assert the seeded code was left alone,
# or a participant who invents a REFUND_EXPIRY window and writes a tidy row scores full marks
# for the exact failure this lab exists to catch.
check(any("seed_intact:" in c.get("check", "") for c in f5_criteria), "F5 criterion also asserts the seeded REFUND_EXPIRY code is byte-for-byte intact")

# The register row-count check must track the finding count. These two drifting apart is the
# specific doc-drift class this repo has already been caught by once.
row_checks = [c for c in criteria if c.get("check", "").startswith("file_table_rows_gte:RISK_REGISTER.md:")]
check(len(row_checks) == 1, "exactly one RISK_REGISTER.md row-count criterion")
if row_checks:
    want_rows = 15  # header + 14 findings
    got_rows = int(row_checks[0]["check"].rsplit(":", 1)[1])
    check(got_rows == want_rows, f"RISK_REGISTER.md row-count check is {want_rows} (header + 14 findings), got {got_rows}")

# Every finding must have its own registration criterion -- otherwise adding a finding to the
# docs without adding it to the rubric is silent.
for i in range(1, 15):
    if i == 8:
        continue  # F8 is scored via f8-registered AND f8-resolved
    check(any(f"f{i}-" in c.get("id", "").lower() for c in criteria), f"F{i} has its own rubric criterion")

# Every sub-check inside an all_of must itself use a known prefix.
for c in criteria:
    chk = c.get("check", "")
    if chk.startswith("all_of:"):
        for sub_chk in chk[len("all_of:"):].split(";"):
            sub_chk = sub_chk.strip()
            if sub_chk:
                check(sub_chk.startswith(known_prefixes), f"all_of sub-check '{sub_chk}' uses a known check type")

print(f"rubric content tests: {pass_count} passed, {fail_count} failed")
sys.exit(1 if fail_count else 0)
PYEOF
