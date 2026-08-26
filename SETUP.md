# Setup Steps: Lab 1 (`arula-mc-labs-fundamentals-governance`)

Follow these steps in order, after you've cloned this repo. This lab is built and tested
against **Claude Code 2.1.108 specifically** — not "whatever version you have." If your
installed CLI is a different version, install/switch to 2.1.108 before continuing (see Step 2).

## Step 1: Install core tooling

- **JDK 17** (Zulu recommended)
- **Maven 3.9+**

Confirm both:
```bash
java -version
mvn -version
```

Also required, but easy to miss since it's not in `mvn compile`'s dependency chain:

- **Python 3**, with the **`pyyaml`** package installed

This repo's hooks and grader are Python scripts. `gate_guard.py` in particular is a *blocking*
hook that runs on every file edit from the moment the plugin loads (Step 4), not just at grading
time, so it needs to work from Stage 0 on.

Confirm Python is installed and `pyyaml` is available:
```bash
python --version    # Windows (python.org installer)
python3 --version   # Mac / Linux
```

Either command printing `Python 3.x.x` is fine — the hooks auto-detect whichever works.

```bash
python -c "import yaml"    # or python3 -c "import yaml"
```

If it errors with `ModuleNotFoundError`, install the package:
```bash
python -m pip install pyyaml    # or python3 -m pip install pyyaml
```

> **Windows notes:**
>
> - **Install Python from [python.org](https://python.org)** and check **"Add Python to PATH"**
>   during install.
>
> - If you see "Python was not found" errors, go to **Settings > Apps > Advanced app settings >
>   App execution aliases** and toggle off `python.exe` and `python3.exe`.
>
> - **Git Bash required** (bundled with [Git for Windows](https://git-scm.com/downloads/win)):
>   ```bash
>   bash --version
>   ```

## Step 2: Confirm you're on Claude Code 2.1.108

```bash
claude --version
```

The output must read `2.1.108`. If it doesn't, install/switch to that version before continuing
— steps in this guide (in particular the plugin install command in Step 4) are written for this
version and may not apply as-written to another one.

## Step 3: Verify the build

From inside the cloned repo directory:

```bash
mvn compile
```

If `mvn compile` succeeds, the repo and your JDK/Maven setup are good.

> **Note:** the first `mvn compile`/`mvn verify` on a cold `~/.m2` resolves dependencies over
> the network like any Maven build. If you're setting up ahead of a live session, run this once
> beforehand so `~/.m2` is warm on session day.

## Step 4: Install the `workbench` plugin

The plugin lives in a small **private** marketplace (not published anywhere public), shipped in
the plugin repo itself. Run both commands, in order:

```bash
claude plugin marketplace add https://github.com/ArulaAI/arula-mc-labs-plugin
claude plugin install workbench@mastercard-workbench
claude plugin install superpowers@claude-plugins-official
```

No separate clone is needed for the plugin — `marketplace add` fetches the repo directly.

**Do not add `-y` to the install command.** That flag does not exist on 2.1.108 and the command
will fail if you include it. Use the plain command exactly as written above.

Also do not use `claude plugin install ./workbench` (a bare local path) — it fails on 2.1.108
with "not found in any configured marketplace." The two-command marketplace flow above is
required, not optional.

## Step 5: Verify the plugin is active

Open Claude Code in the repo directory. With the plugin installed, its rules, agents, hooks, and
commands activate automatically — there is no separate per-repo install step beyond Step 4.

In Claude Code, run:
```
/lab
```

This should report the lab number, title, rubric path, and objectives from `.claude/lab.json`.

Then confirm a journey event actually landed on disk, not just that the command exited cleanly:
```bash
ls .claude/journey/
```
You should see at least one `.jsonl` file. On Windows, this is where a silent Git-Bash/PATH issue
would otherwise surface much later, at Stage 6, instead of now — if no file appears, re-check
Step 1's Git Bash requirement before going further.

## Step 6: Run the hook verification script

This script fires every hook (plugin + repo-local) with realistic payloads and checks they all
resolve Python and execute without errors. Run it from the repo root:

```bash
bash scripts/verify-hooks.sh
```

It tests 14 things in about 5 seconds:

| Check | What it proves |
|---|---|
| Plugin discovery | The `workbench` plugin is installed and locatable |
| `resolve-python` | The plugin's Python resolver runs and finds Python 3.8+ |
| Cache file valid | The resolved Python path was cached and is executable |
| pyyaml | The grader's dependency is installed |
| `journey_record.py` x4 | session-start, pre-tool, post-tool, and stop events all fire via `run-python` |
| `quality_gates.py` | Secret scan + lint gate runs via `run-python` without crashing |
| Journey file written | Events actually landed on disk, not just exit 0 |
| `gate_guard.py` allow | Read on a gated path is correctly allowed (via cached Python path) |
| `gate_guard.py` block | Write to `reference/` is correctly blocked |
| `gate_guard.py` --self-test | All 4 bypass classes + controls pass (16 cases) |
| `grade_repo.py` | The grader runs without Python errors (score will be low -- expected) |

If you see `ALL 14 CHECKS PASSED`, your machine is ready. If any check fails, the output tells
you exactly what to fix.

> **Tip:** On Windows, if you see "Python was not found" in the output, revisit Step 1's
> Windows notes about disabling the App Execution Aliases for `python.exe` and `python3.exe`.

## You're ready

Once Steps 1-6 all pass, you're ready to start Stage 0. The stage-by-stage walkthrough — exact
prompts, minute budgets, and checkpoints — is in [`LAB_ACTION_GUIDE.md`](LAB_ACTION_GUIDE.md).
