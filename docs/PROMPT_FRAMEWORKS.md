# Prompt Frameworks: Quick Reference

Use the minimum prompt structure the task actually needs. More structure does not mean a better
prompt. Clear outcome + relevant context + appropriate constraints + success criteria +
verifiable output does.

---

## 1. Prompt composition frameworks

Choose one based on how much structure the task needs.

| Framework | Components | Use when | Avoid when |
|---|---|---|---|
| **RTF** (Role-Task-Format) | Role (optional) + task + output format | Simple, single-step tasks with a clear output shape | The task needs context the model doesn't already have |
| **RACE** (Role-Action-Context-Expectation) | Who + what + background/evidence + expected outcome | The task needs lightweight context or authoritative evidence before execution | The task is simple enough for plain language |
| **RISEN** (Role-Instructions-Steps-End goal-Narrowing) | Role + instructions + ordered steps + end goal + scope constraints | The **process or ordering** itself matters, not just the outcome | You're adding steps just to look thorough — modern reasoning models handle this natively |
| **CO-STAR** (Context-Objective-Style-Tone-Audience-Response) | Full communication framing including audience and tone | Audience, tone, and style genuinely matter (stakeholder comms, user-facing docs) | Engineering tasks where tone is irrelevant |

**Default engineering prompt contract.** When no acronym fits cleanly, structure around:

- **Outcome**: what you need produced
- **Context / evidence**: authoritative inputs the model should ground its work in
- **Constraints / boundaries**: what's in scope, what's explicitly out
- **Success criteria**: how to tell the output is correct
- **Output contract**: format, location, structure
- **External validation**: how the result will be verified (tests, review, linter, human gate)

## 2. Prompting techniques

These are tools you apply *within* any composition framework, not frameworks themselves.

| Technique | Use when | Avoid when |
|---|---|---|
| **Few-Shot examples** | Pattern learning, classification, formatting, edge-case disambiguation. 3-5 relevant, diverse examples in `<example>` tags. | The task is straightforward and examples add bulk without clarifying anything |
| **Structured output** | The output must match a schema (JSON, table, specific columns) | Free-form output is acceptable |
| **Constraints / negative constraints** | Scope-fencing: explicit inclusions and exclusions to prevent drift | The task is narrow enough that drift isn't a risk |
| **XML tags** (`<context>`, `<instructions>`, `<constraints>`) | Complex prompts mixing instructions, context, examples, and inputs — XML separates them unambiguously | Simple prompts where tags add noise |
| **Prompt chaining** | Intermediate checkpoints, isolation between steps, different authority levels, or deterministic gates matter | The model can handle the full reasoning internally in one pass |

## 3. Reasoning and search techniques

Modern reasoning models handle multi-step logic natively. Do not universally prescribe "think
step by step." Specify outcome, evidence, constraints, and success criteria; let the model
reason.

| Technique | Use when | Avoid when |
|---|---|---|
| **Outcome-first reasoning** | Default for most tasks: state the outcome and let Claude's native reasoning handle the path | Never — this is the baseline |
| **Explicit reasoning scaffold** | The process itself is the deliverable (audit trail, decision log) or evaluations prove the scaffold helps | You're adding steps hoping the model "tries harder" — it won't |
| **Self-consistency** | Multiple plausible solutions exist and you want the most robust one (candidate comparison) | There's one obvious path and generating alternatives wastes tokens |

**For auditability**, prefer visible artifacts over hidden reasoning: decision, evidence cited,
assumptions stated, risks identified, verification performed. Hidden model thinking is not an
audit artifact.

---

## What this lab uses

| Prompt | Stage | Structure | Subagent? | Why this level |
|---|---|---|---|---|
| Comprehension table | 1.3 | Task + output format (RTF) | No | Single task, clear table shape |
| Risk register | 1.5 | Task + constraints | No | Output format + one critical constraint (F5 escalation) |
| Remediation plan | 2 | Outcome + context + constraints + output contract | `planner` | Structured input (register + spec) → ordered plan; isolated context |
| Failing tests | 3 | Task + constraints + negative constraints | No | Prescriptive by design for grading determinism |
| Fix F1/F2 | 4.1a/4.2a | Task + constraint (RTF) | No | Smallest-diff fix, one file, one finding |
| Review F1/F2 | 4.1c/4.2c | Outcome + context + success criteria | `pr-reviewer` | Diff + standards → PASS/FAIL verdict; fresh-context isolation |
| Build online refund | 4.4 | Task + context + negative constraints | No | Scope-fencing against adjacent findings (F6/F12/F13) |
| Secure features guide | 5 | Outcome + context + constraints + output contract | `planner` (guide) | Register → forward-looking guide doc; isolated context |

---

## Further reading

- [Prompting best practices](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)
- [Prompt engineering overview](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [PromptHub: Prompt Engineering for AI Agents](https://www.prompthub.us/blog/prompt-engineering-for-ai-agents)
- [Promptary: 20 Prompt Engineering Frameworks (2026)](https://promptary.dev/frameworks/)
