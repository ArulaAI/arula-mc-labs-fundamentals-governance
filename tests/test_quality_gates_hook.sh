#!/usr/bin/env bash
# test_quality_gates_hook.sh — asserts the unknown-dependency gate catches the
# lab's central FM1 hallucination trap (a fake com.mastercard:pan-vault
# dependency), plus asserts a real cardholder-data leak is flagged, and a
# clean run passes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/quality-gates.sh"

pass=0
fail=0
check() {
    if [ "$1" = "0" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $2" >&2; fi
}

setup_lab() {
    local dir="$1"
    mkdir -p "$dir/.claude" "$dir/src/main/java/com/mc/auth"
    (cd "$dir" && git init -q)
    cat > "$dir/pom.xml" <<'EOF'
<project>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
  </dependencies>
</project>
EOF
}

MVN_VERIFY_PAYLOAD='{"session_id":"sess_qg","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"mvn verify"},"tool_result":{"output":"BUILD SUCCESS","exit_code":0}}'

# --- Test 1: clean repo, first run establishes baseline, all gates PASS/SKIP ---
T1="$(mktemp -d)"
setup_lab "$T1"
(cd "$T1" && echo "$MVN_VERIFY_PAYLOAD" | bash "$HOOK" >/tmp/qg1.out 2>&1)
grep -q '"cardholder-data":"PASS"' "$T1/.claude/quality-gates-latest.json" && check 0 "clean repo: cardholder-data gate PASS" || check 1 "clean repo: cardholder-data gate PASS"
grep -q '"unknown-dependency":"PASS"' "$T1/.claude/quality-gates-latest.json" && check 0 "clean repo: unknown-dependency gate PASS (baseline established)" || check 1 "clean repo: unknown-dependency gate PASS (baseline established)"
rm -rf "$T1"

# --- Test 2: PAN leaked in target/auth-audit.log must FAIL the cardholder-data gate ---
T2="$(mktemp -d)"
setup_lab "$T2"
mkdir -p "$T2/target"
echo "INFO authorized card=4111111111111111 cvv=123" > "$T2/target/auth-audit.log"
(cd "$T2" && echo "$MVN_VERIFY_PAYLOAD" | bash "$HOOK" >/tmp/qg2.out 2>&1)
grep -q '"cardholder-data":"FAIL"' "$T2/.claude/quality-gates-latest.json" && check 0 "planted PAN leak: cardholder-data gate FAILs" || check 1 "planted PAN leak: cardholder-data gate FAILs"
rm -rf "$T2"

# --- Test 3: the FM1 trap — com.mastercard:pan-vault added to pom.xml must WARN ---
T3="$(mktemp -d)"
setup_lab "$T3"
(cd "$T3" && echo "$MVN_VERIFY_PAYLOAD" | bash "$HOOK" >/dev/null 2>&1)   # establish baseline
cat > "$T3/pom.xml" <<'EOF'
<project>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>com.mastercard</groupId><artifactId>pan-vault</artifactId></dependency>
  </dependencies>
</project>
EOF
(cd "$T3" && echo "$MVN_VERIFY_PAYLOAD" | bash "$HOOK" >/tmp/qg3.out 2>&1)
grep -q '"unknown-dependency":"WARN"' "$T3/.claude/quality-gates-latest.json" && check 0 "FM1 trap: com.mastercard:pan-vault flagged WARN" || check 1 "FM1 trap: com.mastercard:pan-vault flagged WARN"
grep -q 'com.mastercard:pan-vault' /tmp/qg3.out && check 0 "FM1 trap: the specific fake coordinate is named in the finding" || check 1 "FM1 trap: the specific fake coordinate is named in the finding"
rm -rf "$T3"

# --- Test 4: non-mvn-verify Bash commands must be a cheap no-op (no .claude/quality-gates-latest.json created) ---
T4="$(mktemp -d)"
setup_lab "$T4"
OTHER_PAYLOAD='{"session_id":"sess_qg","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"},"tool_result":{"output":"","exit_code":0}}'
(cd "$T4" && echo "$OTHER_PAYLOAD" | bash "$HOOK" >/dev/null 2>&1)
if [ -f "$T4/.claude/quality-gates-latest.json" ]; then check 1 "non-mvn command is a no-op"; else check 0 "non-mvn command is a no-op"; fi
rm -rf "$T4"

echo "quality_gates hook tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
