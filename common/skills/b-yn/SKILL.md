---
name: b-yn
description: Use this skill when the user prefixes a prompt with "/b-yn" or asks for a strict yes-or-no answer. Triggers include "/b-yn is this file valid JSON", "/b-yn does this function handle null", "/b-yn should I use X here", "just yes or no", "answer only yes or no", or any phrasing pairing a question with a one-word yes/no verdict. Everything after the trigger is the question. Reads or inspects only what is strictly required to decide, then replies with exactly `Yes` or `No` and nothing else — no explanation, no caveats, no follow-up, no changes.
version: 1.0.0
---

# Answer Yes or No

The text after `/b-yn` is a question. The entire final reply must be exactly one word: `Yes` or `No`.

## Rules

- Output exactly `Yes` or `No`. No punctuation, no prose before or after, no markdown, no code block, no emoji, no explanation.
- Do not modify anything. No file edits, no writes, no commands that change state, no commits, no messages to external services.
- Do not ask clarifying questions. If the question is ambiguous, pick the most reasonable reading and answer it.
- Do not hedge. "It depends", "Maybe", "Mostly yes", "Yes, but..." are all forbidden. Commit to `Yes` or `No`.
- If the question is not yes/no shaped, answer whether the implied claim holds. "Is X better than Y?" and "X is better than Y, right?" both get a `Yes` or `No`.
- If the question is empty, reply `No`.

## Steps

1. Read the question. Decide the minimum evidence needed to answer it honestly.
2. If it needs evidence from the codebase or environment, gather it with read-only tools only: reading files, searching, listing, `git status`/`git log`/`git diff`, dry-run style commands. Stop as soon as the answer is clear.
3. If it needs no evidence (general knowledge, judgment, opinion), skip tools entirely.
4. Reply with `Yes` or `No`.

## Examples

`/b-yn is common/.claude/settings.json valid JSON` -> read the file, parse it -> `Yes`

`/b-yn does the current branch have uncommitted changes` -> `git status --porcelain` -> `Yes`

`/b-yn is PowerShell case-sensitive for variable names` -> no tools -> `No`

`/b-yn should I rename this function` -> judgment call, no hedging -> `Yes`
