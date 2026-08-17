#!/usr/bin/env python3
"""grade_repo.py -- repo-local deterministic grader for Lab 1.

Why this lives in the repo
--------------------------
`/grade` runs the `workbench` plugin's `lab-grader` skill. That skill's engine implements the
check vocabulary this repo's rubric uses -- except the content checks
(`file_contains`, `file_contains_all`, `file_row_contains_all`, `file_table_rows_gte`,
`file_secret_scan_clean`) were never released in the plugin's `0.1.0`. Without them, a rubric
that leans on repo-artifact content silently scores nothing. This script is the lab-local
stopgap: same rubric file, same checks, same deterministic result, no plugin required.

    python3 .claude/scripts/grade_repo.py

Determinism is the contract. Given the same repo contents and the same journey files, this
always produces the same score. Nothing here samples, shells out to a model, or depends on
wall-clock time.

Check vocabulary
----------------
    event_exists:<name>              a journey event of that type was recorded
    event_contains:<substring>       that substring appears anywhere in the journey log
    event_count_gte:<n>              at least n journey events recorded
    secret_scan_clean                no PAN/secret pattern in the journey log
    file_contains:<path>:<kw>        keyword appears anywhere in the file
    file_contains_all:<path>:<k,k>   all keywords appear somewhere in the file
    file_row_contains_all:<path>:<k,k>
                                     all keywords co-occur on ONE line
    file_table_row_contains_all:<path>:<k,k>
                                     as above, but the line must be a WELL-FORMED table row:
                                     at least 4 populated cells, and documenting exactly one
                                     finding id. This is the anti-cramming check.
    file_table_rows_gte:<path>:<n>   file has >= n non-separator, non-empty table rows
    file_secret_scan_clean:<path>    no PAN/secret pattern in that file
    seed_intact:<fixture-id>         a seeded finding's code is byte-for-byte unmodified
    all_of:<check>;<check>;...       every sub-check must pass

What this cannot prove, stated rather than papered over
-------------------------------------------------------
The same structural limitation the rubric's own header documents applies here: a journey event
records that a tool ran, not what it returned, so no check below can prove `mvn verify` went
green. And a correctly-shaped register looks identical whether a participant found the findings
or copied them out of `AGENTS.md`. The facilitator's mandatory Stage 1->2 spot-check is the
control for that, not this script. See `docs/FACILITATOR_KEY.md`.

Self-test: `python3 .claude/scripts/grade_repo.py --self-test` builds synthetic repos (empty,
fully populated, crammed-single-row, F5-defaulted) and asserts the grader scores each the way
it is supposed to.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import sys
import tempfile

try:
    import yaml
except ImportError:  # pragma: no cover
    print(
        "grade_repo.py needs PyYAML (a documented plugin prerequisite):\n"
        "    python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    sys.exit(3)


DEFAULT_RUBRIC = ".claude/rubrics/finish-the-refund.rubric.yaml"
DEFAULT_JOURNEY_DIR = ".claude/journey"
FIXTURE_DIR = ".claude/fixtures"


# =============================================================================================
# secret scanning
# =============================================================================================

# Deliberately narrow. A grader that cries wolf on ordinary prose is a grader facilitators learn
# to ignore, which is worse than no scan at all -- so PAN detection is Luhn-validated rather
# than "any long digit run", and the credential patterns all require an assignment.
_PAN_CANDIDATE = re.compile(r"(?<![0-9])(?:[0-9][ -]?){12,18}[0-9](?![0-9])")
_SECRET_PATTERNS = [
    ("authorization code",
     re.compile(r"\bAUTH-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}")),
    ("CVV/CVC value",
     re.compile(r"\b(?:cvv|cvc|cvv2|cid)\b\s*[:=]\s*[\"']?\d{3,4}\b", re.IGNORECASE)),
    ("credential assignment",
     re.compile(r"\b(?:api[_-]?key|secret[_-]?key|access[_-]?token|password|passwd)\b"
                r"\s*[:=]\s*[\"']?[A-Za-z0-9_\-./+]{12,}", re.IGNORECASE)),
    ("private key block",
     re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----")),
]


def _luhn_ok(digits: str) -> bool:
    total = 0
    for i, ch in enumerate(reversed(digits)):
        d = ord(ch) - 48
        if i % 2 == 1:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


def scan_secrets(text: str) -> list[str]:
    """Return a list of human-readable findings. Empty list means clean."""
    findings: list[str] = []
    for label, rx in _SECRET_PATTERNS:
        if rx.search(text):
            findings.append(label)
    for match in _PAN_CANDIDATE.finditer(text):
        digits = re.sub(r"[ -]", "", match.group(0))
        if 13 <= len(digits) <= 19 and _luhn_ok(digits):
            findings.append("PAN-shaped, Luhn-valid number")
            break
    return findings


# =============================================================================================
# repo / journey access
# =============================================================================================

class Repo:
    """Everything a check needs to read, loaded once so grading is a pure function of it."""

    def __init__(self, root: str):
        self.root = os.path.realpath(root)
        self._file_cache: dict[str, str | None] = {}
        self.journey_files = self._find_journey_files()
        self.journey_text = ""
        self.journey_events: list[dict] = []
        self._load_journey()

    # -- files ---------------------------------------------------------------------------

    def read(self, relpath: str) -> str | None:
        if relpath in self._file_cache:
            return self._file_cache[relpath]
        full = os.path.join(self.root, relpath)
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read()
        except OSError:
            content = None
        self._file_cache[relpath] = content
        return content

    # -- journey -------------------------------------------------------------------------

    def _find_journey_files(self) -> list[str]:
        """Glob, never assume a single filename.

        The journey log fragments: one file per session id, and a lab run that reconnects or
        restarts produces several. Hard-coding `<session_id>.jsonl` would grade only whichever
        fragment happened to be guessed. Sorted so the result is stable.
        """
        configured = os.environ.get("WORKBENCH_JOURNEY_DIR", DEFAULT_JOURNEY_DIR)
        if not os.path.isabs(configured):
            configured = os.path.join(self.root, configured)
        return sorted(glob.glob(os.path.join(configured, "*.jsonl")))

    def _load_journey(self) -> None:
        chunks: list[str] = []
        for path in self.journey_files:
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as fh:
                    for line in fh:
                        line = line.strip()
                        if not line:
                            continue
                        chunks.append(line)
                        try:
                            obj = json.loads(line)
                        except ValueError:
                            continue  # a torn final line is normal for an append-only log
                        if isinstance(obj, dict):
                            self.journey_events.append(obj)
            except OSError:
                continue
        self.journey_text = "\n".join(chunks)

    def event_types(self) -> set[str]:
        """Every plausible 'what kind of event is this' value seen in the log.

        The exact key journey_record.py uses is not pinned down anywhere this repo controls,
        so several are accepted. Being liberal here risks a false pass on a malformed log;
        being strict risks failing every legitimate participant because of a key rename in a
        component this repo does not own. For a 5-point harness-confirmation criterion, the
        liberal direction is the right trade -- and it is written down rather than implied.
        """
        found: set[str] = set()
        for ev in self.journey_events:
            for key in ("event", "type", "event_type", "hook_event_name", "name", "kind"):
                val = ev.get(key)
                if isinstance(val, str) and val.strip():
                    found.add(val.strip().lower())
        return found


# =============================================================================================
# table / row helpers
# =============================================================================================

_SEPARATOR_ROW = re.compile(r"^\s*\|[\s:|-]+\|\s*$")

# A finding id, word-bounded so `F1` does not match inside `F14`.
_FINDING_ID = re.compile(r"\bF(?:[1-9]|1[0-4])\b")

# A real register/fixes row fills most of its columns. RISK_REGISTER.md has 7 and FIXES.md has
# 6, so 4 populated cells is a floor that no honest row trips over and no two-cell crammed line
# clears.
MIN_REGISTER_CELLS = 4

_HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)

# How much authored text a `##` section needs before it counts as filled in. Low enough that a
# terse-but-real hand-off entry passes, high enough that a stray word does not.
MIN_SECTION_CHARS = 40


def strip_html_comments(text: str) -> str:
    """Remove `<!-- ... -->` blocks.

    Load-bearing for grading integrity, not cosmetic. Every template in this repo carries its
    instructions in HTML comments -- and those instructions helpfully name the exact artifacts
    the rubric looks for. A plain whole-file `file_contains_all` therefore scores an *untouched*
    template at full marks: confirmed directly, `docs/workflow-tracker.md` and `SECURITY.md`
    together handed out 20 points on a repo where nobody had done anything. Stripping comments
    first means the keywords have to appear in content a participant actually wrote.
    """
    return _HTML_COMMENT.sub(" ", text)


def iter_sections(text: str):
    """Yield (heading, body) for each `##`/`###` section, with HTML comments stripped."""
    cleaned = strip_html_comments(text)
    heading = None
    body: list[str] = []
    for line in cleaned.splitlines():
        if line.lstrip().startswith("##"):
            if heading is not None:
                yield heading, "\n".join(body)
            heading = line.lstrip("# ").strip()
            body = []
        elif heading is not None:
            body.append(line)
    if heading is not None:
        yield heading, "\n".join(body)


def table_rows(text: str) -> list[str]:
    """Markdown table rows that carry actual content.

    Separator rows (`|---|---|`) and all-blank template rows (`| | | |`) are excluded. That
    exclusion is the point: `RISK_REGISTER.md` ships with a header plus one empty row, so an
    untouched template must not satisfy a row-count check, and a participant cannot pad the
    count with blank rows.
    """
    rows: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        if _SEPARATOR_ROW.match(stripped):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        if not any(cells):
            continue
        rows.append(stripped)
    return rows


# =============================================================================================
# checks
# =============================================================================================

class CheckError(Exception):
    """The rubric asked for something this grader does not implement."""


def split_check(spec: str, expected_parts: int) -> list[str]:
    parts = spec.split(":", expected_parts - 1)
    if len(parts) != expected_parts:
        raise CheckError(f"malformed check '{spec}'")
    return parts


def run_check(spec: str, repo: Repo) -> tuple[bool, str]:
    """Evaluate one check string. Returns (passed, detail)."""
    spec = (spec or "").strip()
    if not spec:
        raise CheckError("empty check")

    # -- all_of ------------------------------------------------------------------------------
    if spec.startswith("all_of:"):
        subs = [s for s in spec[len("all_of:"):].split(";") if s.strip()]
        if not subs:
            raise CheckError("all_of with no sub-checks")
        details = []
        ok = True
        for sub in subs:
            sub_ok, sub_detail = run_check(sub.strip(), repo)
            details.append(("PASS" if sub_ok else "FAIL") + " " + sub.strip() +
                           (f" -- {sub_detail}" if sub_detail else ""))
            ok = ok and sub_ok
        return ok, " | ".join(details)

    # -- journey checks ------------------------------------------------------------------------
    if spec == "secret_scan_clean":
        if not repo.journey_files:
            return False, "no journey files found under the configured journey dir"
        hits = scan_secrets(repo.journey_text)
        return (not hits), ("clean" if not hits else "found: " + ", ".join(sorted(set(hits))))

    if spec.startswith("event_exists:"):
        _, want = split_check(spec, 2)
        want_l = want.strip().lower()
        types = repo.event_types()
        if want_l in types:
            return True, f"event '{want}' recorded"
        # fall back to a substring sweep of the raw log -- see event_types()'s note
        if re.search(re.escape(want_l), repo.journey_text.lower()):
            return True, f"event '{want}' found in the journey log text"
        return False, f"no '{want}' event in {len(repo.journey_files)} journey file(s)"

    if spec.startswith("event_contains:"):
        _, want = split_check(spec, 2)
        hit = want.strip().lower() in repo.journey_text.lower()
        return hit, ("found" if hit else f"'{want}' not present in the journey log")

    if spec.startswith("event_count_gte:"):
        _, raw_n = split_check(spec, 2)
        try:
            n = int(raw_n.strip())
        except ValueError as ex:
            raise CheckError(f"event_count_gte needs an integer: {spec}") from ex
        got = len(repo.journey_events)
        return got >= n, f"{got} event(s), needed {n}"

    # -- file checks ---------------------------------------------------------------------------
    if spec.startswith("file_secret_scan_clean:"):
        _, path = split_check(spec, 2)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        hits = scan_secrets(text)
        return (not hits), ("clean" if not hits else "found: " + ", ".join(sorted(set(hits))))

    if spec.startswith("file_table_rows_gte:"):
        _, path, raw_n = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        try:
            n = int(raw_n.strip())
        except ValueError as ex:
            raise CheckError(f"file_table_rows_gte needs an integer: {spec}") from ex
        rows = table_rows(text)
        return len(rows) >= n, f"{len(rows)} content row(s), needed {n}"

    if spec.startswith("file_row_contains_all:"):
        _, path, raw_kw = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        keywords = [k.strip().lower() for k in raw_kw.split(",") if k.strip()]
        if not keywords:
            raise CheckError(f"no keywords in {spec}")
        for line in text.splitlines():
            low = line.lower()
            if all(k in low for k in keywords):
                return True, "all keywords co-occur on one line"
        return False, f"no single line contains all of: {', '.join(keywords)}"

    if spec.startswith("file_table_row_contains_all:"):
        _, path, raw_kw = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        keywords = [k.strip().lower() for k in raw_kw.split(",") if k.strip()]
        if not keywords:
            raise CheckError(f"no keywords in {spec}")
        saw_keywords_but_crammed = False
        for row in table_rows(text):
            low = row.lower()
            if not all(k in low for k in keywords):
                continue
            cells = [c.strip() for c in row.strip("|").split("|")]
            if len([c for c in cells if c]) < MIN_REGISTER_CELLS:
                saw_keywords_but_crammed = True
                continue
            ids = set(_FINDING_ID.findall(row.upper()))
            if len(ids) > 1:
                saw_keywords_but_crammed = True
                continue
            return True, "found on a well-formed table row"
        if saw_keywords_but_crammed:
            return False, ("keywords found only on a crammed row -- a real register row has at "
                           f"least {MIN_REGISTER_CELLS} populated cells and documents exactly "
                           "one finding")
        return False, f"no table row contains all of: {', '.join(keywords)}"

    if spec.startswith("file_contains_all:"):
        _, path, raw_kw = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        low = text.lower()
        keywords = [k.strip().lower() for k in raw_kw.split(",") if k.strip()]
        if not keywords:
            raise CheckError(f"no keywords in {spec}")
        missing = [k for k in keywords if k not in low]
        return (not missing), ("all present" if not missing else "missing: " + ", ".join(missing))

    if spec.startswith("file_contains_all_uncommented:"):
        _, path, raw_kw = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        low = strip_html_comments(text).lower()
        keywords = [k.strip().lower() for k in raw_kw.split(",") if k.strip()]
        if not keywords:
            raise CheckError(f"no keywords in {spec}")
        missing = [k for k in keywords if k not in low]
        if missing:
            in_comments = [k for k in missing if k in text.lower()]
            note = ""
            if in_comments:
                note = (" -- present ONLY inside the template's own HTML instruction comments, "
                        "which is the template, not an answer")
            return False, "missing: " + ", ".join(missing) + note
        return True, "all present in authored content"

    if spec.startswith("file_sections_nonempty:"):
        _, path, raw_n = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        try:
            n = int(raw_n.strip())
        except ValueError as ex:
            raise CheckError(f"file_sections_nonempty needs an integer: {spec}") from ex
        filled = [name for name, body in iter_sections(text)
                  if len(body.strip()) >= MIN_SECTION_CHARS]
        return len(filled) >= n, (f"{len(filled)} of {n} required sections have authored content"
                                  + (f" ({', '.join(filled)})" if filled else ""))

    if spec.startswith("file_contains:"):
        _, path, kw = split_check(spec, 3)
        text = repo.read(path.strip())
        if text is None:
            return False, f"{path} not found"
        hit = kw.strip().lower() in text.lower()
        return hit, ("found" if hit else f"'{kw.strip()}' not present")

    # -- seed integrity ------------------------------------------------------------------------
    if spec.startswith("seed_intact:"):
        _, fixture_id = split_check(spec, 2)
        return check_seed_intact(fixture_id.strip(), repo)

    raise CheckError(f"unknown check type: '{spec}'")


def check_seed_intact(fixture_id: str, repo: Repo) -> tuple[bool, str]:
    """Assert a seeded finding's code is byte-for-byte what shipped.

    A keyword check on `RISK_REGISTER.md` proves a participant *wrote down* the finding. It
    proves nothing about whether they also quietly "fixed" it. For F5 that distinction is the
    entire lesson: inventing a REFUND_EXPIRY window is the failure the lab is built to catch,
    and a participant who invents one and *also* writes a tidy register row would otherwise
    score full marks for the exact behaviour the lab exists to prevent.
    """
    fixture_path = os.path.join(FIXTURE_DIR, f"{fixture_id}.json")
    raw = repo.read(fixture_path)
    if raw is None:
        return False, f"fixture {fixture_path} not found"
    try:
        fixture = json.loads(raw)
    except ValueError as ex:
        return False, f"fixture {fixture_path} is not valid JSON: {ex}"

    target = fixture.get("target")
    text = repo.read(target) if target else None
    if text is None:
        return False, f"seed target {target} not found"

    for expected in fixture.get("expect_exact", []):
        if expected not in text:
            label = expected.strip().splitlines()[0][:70] if expected.strip() else "<blank>"
            return False, f"seeded block modified in {target} (missing, starting: {label!r})"

    haystacks = [(target, text)]
    for extra in fixture.get("also_scan", []):
        extra_text = repo.read(extra)
        if extra_text is not None:
            haystacks.append((extra, extra_text))

    for pattern in fixture.get("forbid_regex", []):
        rx = re.compile(pattern, re.IGNORECASE)
        for where, hay in haystacks:
            m = rx.search(hay)
            if m:
                return False, (f"forbidden pattern matched in {where}: {m.group(0)[:80]!r} "
                               f"-- the gap appears to have been defaulted rather than escalated")

    return True, "seeded code byte-for-byte intact"


# =============================================================================================
# grading
# =============================================================================================

def grade(repo_root: str, rubric_path: str) -> dict:
    repo = Repo(repo_root)
    rubric_text = repo.read(rubric_path)
    if rubric_text is None:
        raise SystemExit(f"rubric not found: {rubric_path}")
    rubric = yaml.safe_load(rubric_text) or {}

    criteria = rubric.get("criteria") or []
    threshold = rubric.get("pass_threshold", 0)

    results = []
    score = 0.0
    total = 0.0
    for crit in criteria:
        cid = crit.get("id", "<no id>")
        max_score = float(crit.get("max_score", 0) or 0)
        total += max_score
        try:
            ok, detail = run_check(crit.get("check", ""), repo)
        except CheckError as ex:
            ok, detail = False, f"GRADER ERROR: {ex}"
        earned = max_score if ok else 0.0
        score += earned
        results.append({
            "id": cid,
            "description": crit.get("description", ""),
            "check": crit.get("check", ""),
            "max_score": max_score,
            "score": earned,
            "passed": ok,
            "detail": detail,
        })

    return {
        "lab": rubric.get("lab"),
        "title": rubric.get("title", ""),
        "rubric": rubric_path,
        "journey_files": [os.path.relpath(p, repo.root) for p in repo.journey_files],
        "journey_events": len(repo.journey_events),
        "score": score,
        "total": total,
        "pass_threshold": threshold,
        "passed": score >= threshold,
        "criteria": results,
    }


def render(card: dict) -> str:
    lines = []
    lines.append(f"Lab {card['lab']} -- {card['title']}")
    lines.append(f"rubric: {card['rubric']}")
    if card["journey_files"]:
        lines.append(f"journey: {len(card['journey_files'])} file(s), "
                     f"{card['journey_events']} event(s) -- {', '.join(card['journey_files'])}")
    else:
        lines.append("journey: none found (event-based criteria cannot pass)")
    lines.append("")
    width = max((len(c["id"]) for c in card["criteria"]), default=10)
    for c in card["criteria"]:
        mark = "PASS" if c["passed"] else "FAIL"
        lines.append(f"  [{mark}] {c['id']:<{width}}  {c['score']:>4.0f}/{c['max_score']:<4.0f} "
                     f" {c['detail']}")
    lines.append("")
    verdict = "PASS" if card["passed"] else "FAIL"
    pct = (100.0 * card["score"] / card["total"]) if card["total"] else 0.0
    lines.append(f"  SCORE: {card['score']:.0f}/{card['total']:.0f} ({pct:.0f}%)   "
                 f"threshold {card['pass_threshold']}   ->  {verdict}")
    return "\n".join(lines)


# =============================================================================================
# self-test
# =============================================================================================

def _write(root: str, relpath: str, content: str) -> None:
    full = os.path.join(root, relpath)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(content)


def self_test(real_root: str, rubric_path: str) -> int:
    """Grade four synthetic repos and assert each scores the way it is supposed to.

    This is the check that the grader is actually load-bearing rather than decorative: a rubric
    that passes an empty repo, or passes a single crammed line, is not grading anything.
    """
    rubric_text = open(os.path.join(real_root, rubric_path), encoding="utf-8").read()
    rubric = yaml.safe_load(rubric_text)
    threshold = rubric["pass_threshold"]

    def scaffold(tmp: str) -> None:
        _write(tmp, rubric_path, rubric_text)
        os.makedirs(os.path.join(tmp, FIXTURE_DIR), exist_ok=True)
        for fixture in glob.glob(os.path.join(real_root, FIXTURE_DIR, "*.json")):
            shutil.copy(fixture, os.path.join(tmp, FIXTURE_DIR, os.path.basename(fixture)))
        # seed targets, copied byte-for-byte so seed_intact can pass in the "good" case
        for fixture in glob.glob(os.path.join(tmp, FIXTURE_DIR, "*.json")):
            with open(fixture, encoding="utf-8") as fh:
                spec = json.load(fh)
            for rel in [spec.get("target")] + list(spec.get("also_scan", [])):
                if not rel:
                    continue
                src = os.path.join(real_root, rel)
                if os.path.isfile(src):
                    dst = os.path.join(tmp, rel)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copy(src, dst)

    def populated(tmp: str) -> None:
        scaffold(tmp)
        header = ("| ID | Name | Severity | Failure mode | Affected files | Impact | Status |\n"
                  "|---|---|---|---|---|---|---|\n")
        files = {
            1: "RefundService", 2: "RefundService", 3: "RefundController",
            4: "PreRiskAssessmentClient", 5: "RefundPrivilege", 6: "RefundService",
            7: "RefundController", 8: "RefundController", 9: "RefundService",
            10: "RefundController", 11: "RefundHealthIndicator", 12: "RefundService",
            13: "RefundService", 14: "RefundService",
        }
        rows = []
        for i in range(1, 15):
            extra = " escalated to the product owner" if i == 5 else ""
            rows.append(f"| F{i} | finding {i}{extra} | High | mode | `{files[i]}.java` | impact | Open |")
        _write(tmp, "RISK_REGISTER.md", header + "\n".join(rows) + "\n")
        _write(tmp, "docs/plans/plan.md", "# Plan\n\n1. Critical first: F1\n2. Then F2\n")
        _write(tmp, "FIXES.md",
               "| ID | Change | Files | Test | Reviewer verdict | Date |\n"
               "|---|---|---|---|---|---|\n"
               "| F1 | logs scrubbed | RefundService.java | RefundLoggingTest | PASS | today |\n"
               "| F2 | idempotency | RefundService.java | RefundIdempotencyTest | PASS | today |\n"
               "| F8 | ArchUnit layering resolved | RefundController.java | ArchitectureIT | PASS | today |\n")
        _write(tmp, "docs/secure-features-guide.md",
               "# Guide\n\n- correlation IDs end to end\n- tokenisation of stored identifiers\n")
        _write(tmp, "SECURITY.md",
               "# Security\n\nControls: F1, F2, F8.\nF5 is escalated, not defaulted.\n")
        tracker = ["# Workflow tracker\n"]
        artifacts = ["the harness check", "RISK_REGISTER.md", "docs/plans/plan.md",
                     "the two red test slices", "FIXES.md",
                     "docs/secure-features-guide.md", "SECURITY.md"]
        for i in range(7):
            tracker.append(
                f"## Stage {i}\n\n"
                f"What we did: completed stage {i} and reviewed the output as a group.\n"
                f"Claude Code helped with: drafting, which we then checked line by line.\n"
                f"Verified by hand: yes, against the spec.\n"
                f"Artifact produced this stage: {artifacts[i]}\n")
        _write(tmp, "docs/workflow-tracker.md", "\n".join(tracker))
        _write(tmp, ".claude/journey/session-a.jsonl",
               '{"event":"session-start","ts":1}\n{"event":"tool","tool":"Read"}\n')
        _write(tmp, ".claude/journey/session-b.jsonl",
               '{"event":"tool","tool":"Edit"}\n{"event":"session-end"}\n')

    cases = []

    # 1. empty repo -- must fail hard
    with tempfile.TemporaryDirectory() as tmp:
        scaffold(tmp)
        card = grade(tmp, rubric_path)
        cases.append(("empty repo scores below threshold",
                      (not card["passed"]) and card["score"] < threshold,
                      f"{card['score']:.0f}/{card['total']:.0f}"))

    # 2. fully populated -- must pass
    with tempfile.TemporaryDirectory() as tmp:
        populated(tmp)
        card = grade(tmp, rubric_path)
        failed = [c["id"] + " (" + c["detail"] + ")" for c in card["criteria"] if not c["passed"]]
        cases.append(("fully-populated repo passes",
                      card["passed"],
                      f"{card['score']:.0f}/{card['total']:.0f}" +
                      ("; failing: " + "; ".join(failed) if failed else "")))

    # 3. crammed single row -- the exploit the rubric header describes. Must fail.
    with tempfile.TemporaryDirectory() as tmp:
        populated(tmp)
        crammed = ("| ID | Name |\n|---|---|\n"
                   "| F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 escalat "
                   "RefundService RefundController PreRiskAssessmentClient RefundPrivilege "
                   "RefundHealthIndicator | everything |\n")
        _write(tmp, "RISK_REGISTER.md", crammed)
        card = grade(tmp, rubric_path)
        cases.append(("crammed single-row register scores below threshold",
                      not card["passed"],
                      f"{card['score']:.0f}/{card['total']:.0f}"))

    # 4. F5 defaulted rather than escalated -- must lose the F5 criterion even with a tidy row.
    with tempfile.TemporaryDirectory() as tmp:
        populated(tmp)
        target = None
        for fixture in glob.glob(os.path.join(tmp, FIXTURE_DIR, "f5*.json")):
            with open(fixture, encoding="utf-8") as fh:
                target = json.load(fh).get("target")
        if target:
            full = os.path.join(tmp, target)
            src = open(full, encoding="utf-8").read()
            src = src.replace("    REFUND_EXPIRY\n",
                              "    REFUND_EXPIRY;\n\n    public static final int "
                              "REFUND_EXPIRY_DAYS = 180;\n")
            with open(full, "w", encoding="utf-8") as fh:
                fh.write(src)
        card = grade(tmp, rubric_path)
        f5 = [c for c in card["criteria"] if c["id"].startswith("f5")]
        cases.append(("F5 defaulted (not escalated) loses the F5 criterion",
                      bool(f5) and not any(c["passed"] for c in f5),
                      "; ".join(f"{c['id']}={c['passed']} ({c['detail']})" for c in f5) or "no F5 criterion!"))

    failures = 0
    for label, ok, detail in cases:
        print(f"{'ok  ' if ok else 'FAIL'}  {label}  --  {detail}")
        if not ok:
            failures += 1
    print()
    print(f"grade_repo self-test: {len(cases) - failures} passed, {failures} failed")
    return 1 if failures else 0


# =============================================================================================
# cli
# =============================================================================================

def find_repo_root(start: str) -> str:
    cur = os.path.realpath(start)
    while True:
        if os.path.isfile(os.path.join(cur, ".claude", "lab.json")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return os.path.realpath(start)
        cur = parent


def main() -> int:
    ap = argparse.ArgumentParser(description="Deterministic lab-local grader for Lab 1.")
    ap.add_argument("--repo", default=None, help="repo root (default: auto-detect)")
    ap.add_argument("--rubric", default=None,
                    help=f"rubric path relative to the repo root (default: from .claude/lab.json, "
                         f"else {DEFAULT_RUBRIC})")
    ap.add_argument("--json", action="store_true", help="emit the grade card as JSON")
    ap.add_argument("--out", default=None, help="also write the JSON grade card here")
    ap.add_argument("--self-test", action="store_true",
                    help="grade synthetic repos and assert the grader discriminates correctly")
    args = ap.parse_args()

    root = os.path.realpath(args.repo) if args.repo else find_repo_root(os.getcwd())

    rubric_path = args.rubric
    if not rubric_path:
        try:
            with open(os.path.join(root, ".claude", "lab.json"), encoding="utf-8") as fh:
                rubric_path = json.load(fh).get("rubric") or DEFAULT_RUBRIC
        except (OSError, ValueError):
            rubric_path = DEFAULT_RUBRIC

    if args.self_test:
        return self_test(root, rubric_path)

    card = grade(root, rubric_path)

    if args.json:
        print(json.dumps(card, indent=2))
    else:
        print(render(card))

    if args.out:
        out = args.out if os.path.isabs(args.out) else os.path.join(root, args.out)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(card, fh, indent=2)
        print(f"\nwrote {out}")

    return 0 if card["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
