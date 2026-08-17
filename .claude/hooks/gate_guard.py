#!/usr/bin/env python3
"""gate_guard.py -- repo-local PreToolUse hook. Blocks writes to denied paths.

Why this lives in the repo rather than coming from the `workbench` plugin
------------------------------------------------------------------------
The plugin ships `quality_gates.py`, which is a *reporting* gate: it scans and warns, it does
not stop a tool call. Nothing in the plugin actually blocks a write. This repo needs a real
block, because `reference/` is the Stage-4 fallback solution and a live session must not be
able to write to it (reading it is the facilitator's call to make, not the model's).

The repo's general rule is that repo-local components must not duplicate plugin-provided ones,
because a local copy silently drifts. This hook is the documented exception to that rule: there
is no plugin equivalent to drift away from. If the plugin ever ships a blocking gate, delete
this file rather than keeping both.

Contract (Claude Code 2.1.x, verified against the hooks reference)
------------------------------------------------------------------
- Invoked as a `PreToolUse` command hook. The event payload arrives as JSON on **stdin**.
- Relevant payload keys: `tool_name`, `tool_input`, `cwd`.
- Exit code **2** blocks the tool call and feeds stderr back to the model. Exit 0 (and any
  other code) allows it. We also emit the structured `permissionDecision: "deny"` object on
  stdout so the block is legible to any harness version that prefers the JSON form.

The four bypass classes this defends against
--------------------------------------------
All four were found and fixed once before in a version of this hook that no longer exists on
disk (see DELIVERY_STATUS.md). They are re-covered here deliberately, and each has a case in
`--self-test`:

1. **Absolute-path bypass** -- deny patterns are repo-relative, so `/Users/.../reference/x.java`
   would not match a naive `fnmatch` against the raw string. Every path is resolved and
   re-expressed relative to the project root before matching.
2. **Relative-path traversal** -- `docs/../reference/x.java`, or a path relative to a `cwd`
   somewhere below the repo root. Normalised with `normpath` (which collapses `..` without
   requiring the file to exist) before matching.
3. **Case-insensitive filesystem** -- on macOS and Windows, `Reference/x.java` and
   `REFERENCE/x.java` open the same file that `reference/**` is meant to protect. Matching is
   attempted case-sensitively and again case-folded.
4. **`NotebookEdit`'s distinct input key** -- it carries `notebook_path`, not `file_path`. A
   hook that only reads `file_path` fails *open* for notebooks, which is the worst failure
   direction. Every known path-bearing key is collected, including nested `edits[].file_path`.

Run `python3 .claude/hooks/gate_guard.py --self-test` to exercise all four plus the
allow-path controls.
"""

from __future__ import annotations

import json
import os
import re
import sys

# Tools that can modify a file on disk. Anything else is allowed straight through: this hook
# is a write gate, not a general policy engine.
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

# Every key any of the above tools has ever used to carry a target path. Collecting all of them
# unconditionally -- rather than switching on tool_name -- is deliberate: if a future tool or a
# renamed field shows up, this fails *closed* (it still finds the path) instead of open.
PATH_KEYS = ("file_path", "notebook_path", "path", "filePath", "notebookPath")

CONFIG_RELPATH = os.path.join(".claude", "gate-guard.json")


# ---------------------------------------------------------------------------------------------
# glob matching
# ---------------------------------------------------------------------------------------------

def glob_to_regex(pattern: str) -> re.Pattern:
    """Translate a deny glob to a regex.

    `fnmatch` is not usable here: its `*` happily crosses `/`, so `reference/*` would match
    `reference/a/b/c` and, worse, a pattern like `*.env` would match paths it was never meant
    to. This implements the conventional shell semantics instead -- `**` crosses separators,
    `*` and `?` do not.
    """
    pattern = pattern.replace("\\", "/").lstrip("./")
    out = ["^"]
    i = 0
    n = len(pattern)
    while i < n:
        ch = pattern[i]
        if ch == "*":
            if i + 1 < n and pattern[i + 1] == "*":
                # `**/` or a trailing `**` -- match across separators, including zero segments.
                i += 2
                if i < n and pattern[i] == "/":
                    i += 1
                    out.append("(?:.*/)?")
                else:
                    out.append(".*")
                continue
            out.append("[^/]*")
        elif ch == "?":
            out.append("[^/]")
        elif ch == "[":
            j = pattern.find("]", i)
            if j == -1:
                out.append(re.escape(ch))
            else:
                out.append("[" + pattern[i + 1:j].replace("\\", "\\\\") + "]")
                i = j + 1
                continue
        else:
            out.append(re.escape(ch))
        i += 1
    out.append("$")
    return re.compile("".join(out))


def expand_patterns(raw_patterns) -> list[str]:
    """Normalise the configured deny list.

    A bare directory entry (`reference` or `reference/`) is treated as protecting the whole
    subtree *and* the directory entry itself -- writing `reference` as a deny rule and having
    it only block a file literally named `reference` would be a trap.
    """
    patterns: list[str] = []
    for raw in raw_patterns or []:
        if not isinstance(raw, str) or not raw.strip():
            continue
        p = raw.strip().replace("\\", "/")
        while p.startswith("./"):
            p = p[2:]
        p = p.lstrip("/")
        if not p:
            continue
        if p.endswith("/"):
            patterns.append(p.rstrip("/"))
            patterns.append(p + "**")
        elif "*" not in p and "?" not in p and "[" not in p:
            # No glob metacharacters -- could be a file or a directory. Cover both.
            patterns.append(p)
            patterns.append(p + "/**")
        else:
            patterns.append(p)
            if p.endswith("/**"):
                # `reference/**` protects the tree; also protect the directory entry itself, so
                # a write whose target is literally `reference` cannot slip past the subtree
                # rule on a technicality.
                patterns.append(p[: -len("/**")])
    return patterns


def matches_any(relpath: str, patterns: list[str]) -> str | None:
    """Return the pattern that blocks `relpath`, or None. Case-sensitive first, then folded."""
    candidates = {relpath, relpath.lstrip("./")}
    for pattern in patterns:
        rx = glob_to_regex(pattern)
        for cand in candidates:
            if rx.match(cand):
                return pattern
        # Bypass class 3: case-insensitive filesystems. `Reference/x` opens the same file as
        # `reference/x` on macOS/Windows, so a case-sensitive-only check fails open there.
        rx_ci = re.compile(rx.pattern, re.IGNORECASE)
        for cand in candidates:
            if rx_ci.match(cand):
                return pattern + " (case-insensitive match)"
    return None


# ---------------------------------------------------------------------------------------------
# path resolution
# ---------------------------------------------------------------------------------------------

def find_project_root(payload_cwd: str | None) -> str | None:
    """Locate the repo root: the env var the harness sets, else walk up looking for the config."""
    env_root = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_root and os.path.isdir(env_root):
        return os.path.realpath(env_root)

    start = payload_cwd or os.getcwd()
    cur = os.path.realpath(start)
    while True:
        if os.path.isfile(os.path.join(cur, CONFIG_RELPATH)):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent


def collect_paths(tool_input) -> list[str]:
    """Pull every candidate target path out of a tool_input blob."""
    found: list[str] = []
    if not isinstance(tool_input, dict):
        return found
    for key in PATH_KEYS:
        val = tool_input.get(key)
        if isinstance(val, str) and val.strip():
            found.append(val)
    # MultiEdit may carry per-edit paths rather than one top-level path.
    edits = tool_input.get("edits")
    if isinstance(edits, list):
        for edit in edits:
            if isinstance(edit, dict):
                for key in PATH_KEYS:
                    val = edit.get(key)
                    if isinstance(val, str) and val.strip():
                        found.append(val)
    return found


def to_relpath(raw_path: str, project_root: str, cwd: str) -> str | None:
    """Resolve any path form to a repo-root-relative POSIX path, or None if outside the repo."""
    p = os.path.expanduser(raw_path.strip())
    if not os.path.isabs(p):
        # Bypass class 2: relative traversal, and paths relative to a cwd below the root.
        p = os.path.join(cwd or project_root, p)
    # normpath collapses `..` without requiring the file to exist (realpath alone would not,
    # and these files often do not exist yet -- Write creates them).
    p = os.path.normpath(p)
    # Then resolve symlinks, on the deepest existing ancestor, so a symlinked directory cannot
    # be used to reach a denied path from outside it.
    p = resolve_existing_prefix(p)

    root = os.path.realpath(project_root)
    try:
        rel = os.path.relpath(p, root)
    except ValueError:
        # Different drive on Windows -- definitionally outside the repo.
        return None
    rel = rel.replace("\\", "/")
    if rel == ".." or rel.startswith("../"):
        return None  # outside the repo; not this hook's business
    return rel


def resolve_existing_prefix(path: str) -> str:
    """realpath the longest existing ancestor, then re-append the non-existent tail."""
    tail: list[str] = []
    cur = path
    while True:
        if os.path.exists(cur):
            break
        parent = os.path.dirname(cur)
        if parent == cur or not parent:
            return path
        tail.append(os.path.basename(cur))
        cur = parent
    resolved = os.path.realpath(cur)
    for part in reversed(tail):
        resolved = os.path.join(resolved, part)
    return resolved


# ---------------------------------------------------------------------------------------------
# decision
# ---------------------------------------------------------------------------------------------

def evaluate(payload: dict) -> tuple[bool, str]:
    """Return (blocked, reason)."""
    tool_name = payload.get("tool_name") or ""
    if tool_name not in WRITE_TOOLS:
        return False, ""

    candidates = collect_paths(payload.get("tool_input"))
    if not candidates:
        return False, ""

    cwd = payload.get("cwd") or os.getcwd()
    project_root = find_project_root(cwd)
    if not project_root:
        return False, ""

    config_path = os.path.join(project_root, CONFIG_RELPATH)
    if not os.path.isfile(config_path):
        return False, ""  # nothing configured, nothing denied

    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            config = json.load(fh)
    except (OSError, ValueError) as ex:
        # Fail CLOSED. A malformed deny list is a broken gate, and a broken gate that allows
        # everything is strictly worse than one that makes itself impossible to ignore.
        return True, (
            f"gate_guard: cannot read {CONFIG_RELPATH} ({ex}). Refusing the write rather than "
            f"proceeding with an unenforceable deny list. Fix the config file."
        )

    patterns = expand_patterns(config.get("deny"))
    if not patterns:
        return False, ""

    for raw in candidates:
        rel = to_relpath(raw, project_root, cwd)
        if rel is None:
            continue
        hit = matches_any(rel, patterns)
        if hit:
            return True, (
                f"gate_guard: blocked {tool_name} to '{rel}'.\n"
                f"Matched deny rule '{hit}' in {CONFIG_RELPATH}.\n"
                f"This path is gated for the lab: reference/ holds the Stage-4 fallback "
                f"solution and stays read-only during a live session. Reading it is the "
                f"facilitator's call. Do not attempt to reach it by another path form -- "
                f"absolute paths, ../ traversal and case variants are all resolved before "
                f"this check."
            )
    return False, ""


def main() -> int:
    try:
        raw = sys.stdin.read()
    except Exception:
        return 0
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except ValueError:
        return 0
    if not isinstance(payload, dict):
        return 0

    try:
        blocked, reason = evaluate(payload)
    except Exception as ex:  # never take the session down over a hook bug
        print(f"gate_guard: internal error, allowing tool call: {ex}", file=sys.stderr)
        return 0

    if not blocked:
        return 0

    # Structured form (honoured on exit 0 by harnesses that prefer it) ...
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    # ... plus exit 2, which is the documented, unambiguous block.
    print(reason, file=sys.stderr)
    return 2


# ---------------------------------------------------------------------------------------------
# self-test
# ---------------------------------------------------------------------------------------------

def self_test() -> int:
    root = find_project_root(os.getcwd())
    if not root:
        print("SELF-TEST ABORTED: could not locate the project root", file=sys.stderr)
        return 1

    def ev(tool, tool_input, cwd=None):
        return evaluate({"tool_name": tool, "tool_input": tool_input, "cwd": cwd or root})[0]

    abs_ref = os.path.join(root, "reference", "RefundService.solved.java")

    cases = [
        # (must_block, label, callable)
        (True, "plain relative path",
         lambda: ev("Write", {"file_path": "reference/RefundService.solved.java"})),
        (True, "BYPASS 1: absolute path",
         lambda: ev("Write", {"file_path": abs_ref})),
        (True, "BYPASS 2: relative traversal via ../",
         lambda: ev("Edit", {"file_path": "docs/../reference/README.md"})),
        (True, "BYPASS 2b: path relative to a cwd below the repo root",
         lambda: ev("Edit", {"file_path": "../reference/README.md"},
                    cwd=os.path.join(root, "docs"))),
        (True, "BYPASS 3: case-insensitive filesystem (Reference/)",
         lambda: ev("Write", {"file_path": "Reference/RefundService.solved.java"})),
        (True, "BYPASS 3b: case-insensitive filesystem (REFERENCE/)",
         lambda: ev("Write", {"file_path": "REFERENCE/README.md"})),
        (True, "BYPASS 4: NotebookEdit's notebook_path key",
         lambda: ev("NotebookEdit", {"notebook_path": "reference/notes.ipynb"})),
        (True, "BYPASS 4b: NotebookEdit, absolute notebook_path",
         lambda: ev("NotebookEdit", {"notebook_path": os.path.join(root, "reference", "n.ipynb")})),
        (True, "MultiEdit with a nested edits[].file_path",
         lambda: ev("MultiEdit", {"edits": [{"file_path": "reference/README.md"}]})),
        (True, "the gated directory itself",
         lambda: ev("Write", {"file_path": "reference"})),
        (True, "nested deeper inside the gated tree",
         lambda: ev("Write", {"file_path": "reference/a/b/c/deep.java"})),
        # controls -- these must NOT block, or the hook is useless during a real session
        (False, "CONTROL: an ordinary source file",
         lambda: ev("Write", {"file_path": "src/main/java/com/mc/pgs/refunds/service/RefundService.java"})),
        (False, "CONTROL: RISK_REGISTER.md, the Stage 1 artifact",
         lambda: ev("Write", {"file_path": "RISK_REGISTER.md"})),
        (False, "CONTROL: a path outside the repo entirely",
         lambda: ev("Write", {"file_path": "/tmp/scratch.txt"})),
        (False, "CONTROL: a non-write tool targeting a gated path",
         lambda: ev("Read", {"file_path": "reference/README.md"})),
        (False, "CONTROL: a filename that merely starts with the deny prefix",
         lambda: ev("Write", {"file_path": "references.md"})),
    ]

    failures = 0
    for want_block, label, fn in cases:
        try:
            got = fn()
        except Exception as ex:
            print(f"FAIL  {label}: raised {ex!r}")
            failures += 1
            continue
        ok = (got == want_block)
        verb = "BLOCK" if want_block else "ALLOW"
        print(f"{'ok  ' if ok else 'FAIL'}  expected {verb:5s} -- {label}")
        if not ok:
            failures += 1

    print()
    print(f"gate_guard self-test: {len(cases) - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main())
