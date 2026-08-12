#!/usr/bin/env bash
# run_all.sh — runs every test in this directory, reports a combined result.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
total_fail=0

for t in "$DIR"/test_*.sh; do
    echo "=== $(basename "$t") ==="
    bash "$t"
    rc=$?
    [ "$rc" -ne 0 ] && total_fail=$((total_fail + 1))
    echo
done

if [ "$total_fail" -eq 0 ]; then
    echo "ALL TEST FILES PASSED"
    exit 0
else
    echo "$total_fail TEST FILE(S) FAILED"
    exit 1
fi
