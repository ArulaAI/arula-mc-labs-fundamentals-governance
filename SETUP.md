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

Confirm both:
```bash
python3 --version
python3 -c "import yaml"
```

The second command should print nothing (success). If it errors with `ModuleNotFoundError`,
install the package:
```bash
python3 -m pip install pyyaml
```

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
You should see at least one `.jsonl` file. On Windows, this is where a silent bash/PATH issue
would otherwise surface much later, at Stage 6, instead of now.

## You're ready

Once Steps 1-5 all pass, you're ready to start Stage 0. The stage-by-stage walkthrough — exact
prompts, minute budgets, and checkpoints — is in [`LAB_ACTION_GUIDE.md`](LAB_ACTION_GUIDE.md).
