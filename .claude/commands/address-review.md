Use the most recent `pr-reviewer` result for $ARGUMENTS.

Address the review findings as follows:
- Fix valid BLOCKERS that are within the approved $ARGUMENTS scope.
- Fix WARNINGS only when they are material to correctness, security, or the approved scope.
- Do not act on speculative, unrelated, or refactoring-only suggestions.
- Make the smallest production-code change necessary.
- Do not modify tests or add dependencies.
- Do not change unrelated behavior.
- Do not run validation.
- Do not self-review or invoke the pr-reviewer.

When complete, report:
- findings addressed
- findings skipped and why
- files changed

Then stop.

If no prior `pr-reviewer` result for $ARGUMENTS is available in the current context, stop and say so rather than guessing.