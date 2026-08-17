#!/usr/bin/env python3
"""anti_gaming_check.py -- does the participant's F1 test actually detect the F1 leak?

The problem this exists for
---------------------------
Every other control in this lab can be satisfied by a test that does not test anything. A
participant (or a model working for one) can write `assertThat(true).isTrue()`, name the class
`RefundLoggingTest`, watch `mvn test` go green after the fix, write a tidy `FIXES.md` row, and
score full marks. Nothing in the rubric can tell that test apart from a real one: both are green
after remediation, and "green after remediation" is all a content check can see.

The check
---------
Mutation testing, scoped to exactly one mutant that matters. Copy the repo to a throwaway
directory, **put the F1 leak back**, and re-run the participant's own F1 test against it.

- Test FAILS with the leak restored -> the test genuinely detects the leak. PASS.
- Test PASSES with the leak restored -> the test never detected anything. FAIL.

That inversion is the whole idea, and it is worth saying out loud to a group afterwards: a test
that cannot fail is not evidence, and the only way to know whether a test can fail is to make
the thing it guards go wrong.

Usage
-----
    python3 .claude/scripts/anti_gaming_check.py                 # auto-detect the F1 test
    python3 .claude/scripts/anti_gaming_check.py --test RefundLoggingTest
    python3 .claude/scripts/anti_gaming_check.py --keep-temp     # leave the mutated copy on disk

Facilitator tool, run after Stage 4. Deliberately NOT wired into `/grade` or the rubric: it
takes a full Maven cycle, and `/grade` is documented as fast and deterministic. Exit codes:
0 = the test is real, 1 = the test does not detect the leak, 2 = inconclusive (no F1 test found,
or the harness could not run).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

FIXTURE = ".claude/fixtures/f1-log-leak.json"

# Copied into the throwaway build. Everything else (docs, .git, target/) is irrelevant to
# whether a test compiles and runs, and copying target/ makes this needlessly slow.
COPY_ENTRIES = ["pom.xml", "src", ".mvn", "mvnw", "mvnw.cmd"]

# How we guess which test class is "the F1 test" when the facilitator does not name one.
F1_SIGNALS = re.compile(
    r"authorizationCode|CapturedOutput|OutputCaptureExtension|AUTH-|authorization code",
    re.IGNORECASE,
)
F1_NAME_HINT = re.compile(r"(log|logging|sensitive|leak|f1|redact|mask)", re.IGNORECASE)


def find_repo_root(start: str) -> str:
    cur = os.path.realpath(start)
    while True:
        if os.path.isfile(os.path.join(cur, ".claude", "lab.json")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return os.path.realpath(start)
        cur = parent


def method_span(source: str, method: str) -> tuple[int, int] | None:
    """Find [start, end) of a method body by brace-matching from its signature."""
    m = re.search(r"\b" + re.escape(method) + r"\s*\(", source)
    if not m:
        return None
    brace = source.find("{", m.end())
    if brace == -1:
        return None
    depth = 0
    i = brace
    while i < len(source):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return brace, i + 1
        i += 1
    return None


def reinject_leak(repo: str, fixture: dict) -> list[str]:
    """Restore the seeded F1 leak in the copied tree. Returns the labels applied."""
    target = os.path.join(repo, fixture["target"])
    with open(target, encoding="utf-8") as fh:
        source = fh.read()

    span = method_span(source, fixture["method"])
    if not span:
        raise SystemExit(f"could not locate {fixture['method']}() in {fixture['target']} -- "
                         f"the method may have been renamed; re-run with the correct name")
    start, end = span
    body = source[start:end]

    applied = []
    for rep in fixture["replacements"]:
        rx = re.compile(rep["find_regex"])
        new_body, count = rx.subn(rep["replace"], body, count=1)
        if count:
            body = new_body
            applied.append(rep["id"])

    with open(target, "w", encoding="utf-8") as fh:
        fh.write(source[:start] + body + source[end:])
    return applied


def discover_f1_tests(repo: str) -> list[str]:
    """Test classes that look like they are about F1. Ranked, best guess first."""
    test_root = os.path.join(repo, "src", "test", "java")
    scored: list[tuple[int, str]] = []
    for dirpath, _dirs, files in os.walk(test_root):
        for name in files:
            if not name.endswith(".java"):
                continue
            cls = name[: -len(".java")]
            if cls in ("ArchitectureIT", "BaselineTest") or cls.endswith("Fixtures"):
                continue
            try:
                with open(os.path.join(dirpath, name), encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
            except OSError:
                continue
            if "@Test" not in text:
                continue
            score = len(F1_SIGNALS.findall(text))
            if F1_NAME_HINT.search(cls):
                score += 3
            if score:
                scored.append((score, cls))
    scored.sort(key=lambda pair: (-pair[0], pair[1]))
    return [cls for _score, cls in scored]


def run_maven(repo: str, test_selector: str) -> tuple[int, str]:
    cmd = ["mvn", "-q", "-Dsurefire.failIfNoSpecifiedTests=false",
           f"-Dtest={test_selector}", "test"]
    proc = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--repo", default=None)
    ap.add_argument("--test", default=None,
                    help="test class to run (default: auto-detect the F1 test)")
    ap.add_argument("--keep-temp", action="store_true",
                    help="leave the mutated copy on disk for inspection")
    args = ap.parse_args()

    root = os.path.realpath(args.repo) if args.repo else find_repo_root(os.getcwd())

    fixture_path = os.path.join(root, FIXTURE)
    if not os.path.isfile(fixture_path):
        print(f"INCONCLUSIVE: fixture not found at {FIXTURE}", file=sys.stderr)
        return 2
    with open(fixture_path, encoding="utf-8") as fh:
        fixture = json.load(fh)

    candidates = [args.test] if args.test else discover_f1_tests(root)
    if not candidates:
        print("INCONCLUSIVE: no F1-looking test class found under src/test/java.")
        print("  Stage 3 should have produced one. If the group named it something this script")
        print("  did not guess, re-run with --test <ClassName>.")
        return 2
    selector = candidates[0]

    tmp = tempfile.mkdtemp(prefix="anti-gaming-")
    try:
        for entry in COPY_ENTRIES:
            src = os.path.join(root, entry)
            if not os.path.exists(src):
                continue
            dst = os.path.join(tmp, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        applied = reinject_leak(tmp, fixture)
        if not applied:
            print("INCONCLUSIVE: could not re-inject the F1 leak -- neither log statement in")
            print(f"  {fixture['method']}() matched the fixture's patterns. The method may have")
            print("  been restructured beyond what this check understands. Review by hand.")
            return 2

        print(f"Re-injected the seeded F1 leak ({', '.join(applied)}) into a throwaway copy.")
        print(f"Running: {selector}")
        if len(candidates) > 1:
            print(f"  (other candidates seen: {', '.join(candidates[1:])})")
        print()

        code, output = run_maven(tmp, selector)

        if code != 0:
            print("PASS -- the test FAILED with the leak restored, which is exactly right.")
            print("  It is a real test: it detects the authorization code reaching the log.")
            return 0

        print("FAIL -- the test PASSED with the F1 leak restored.")
        print()
        print("  That means it never detected the leak. It went green after the Stage 4 fix,")
        print("  but it would have gone green without one. Whatever it asserts, it is not")
        print("  asserting that the authorization code stays out of the logs.")
        print()
        print("  Walk the group through it: point at the assertion, restore the leak in front")
        print("  of them, and show the test staying green. Then ask what the test was for.")
        tail = "\n".join(output.strip().splitlines()[-15:])
        if tail:
            print()
            print("  Maven output (tail):")
            for line in tail.splitlines():
                print("    " + line)
        return 1
    finally:
        if args.keep_temp:
            print(f"\nmutated copy left at: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
