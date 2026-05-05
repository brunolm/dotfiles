---
name: brunolm-code-review
description: Use this skill when the user asks for a code review, wants feedback on changes, or says things like "review my code", "review this branch", "review this PR", "review the diff", "what do you think of these changes", or "look over my changes". Reviews either the current branch diff, uncommitted working-tree changes, or a specified GitHub PR, and reports findings grouped by severity.
version: 1.0.0
allowed-tools:
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status:*)
  - Bash(git merge-base:*)
  - Bash(git rev-parse:*)
  - Bash(git show:*)
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr checks:*)
  - Bash(echo:*)
  - Bash(sed:*)
  - Read
  - Grep
  - Glob
---

# Code Review

Perform a focused code review of the user's changes and return findings grouped by severity.

## Scope selection

Pick scope in this order:

1. If the user passes a PR number or URL (`#123`, `https://github.com/.../pull/123`) - review that PR via `gh pr diff <n>` and `gh pr view <n> --json title,body,author,baseRefName,headRefName,additions,deletions,files`.
2. If the user passes a ref (`main`, `HEAD~3`, `abc123..def456`) - diff against that ref.
3. If the working tree has uncommitted changes (`git status --porcelain` non-empty) and the user said "my changes" / "what I'm working on" - review working-tree diff (`git diff HEAD`).
4. Otherwise - review the current branch against its merge-base with the main branch:
   ```bash
   BASE=$(git merge-base HEAD "$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')" 2>/dev/null || git merge-base HEAD master 2>/dev/null || git merge-base HEAD main)
   git diff "$BASE"...HEAD
   ```

State the chosen scope in one line before diving in (e.g., "Reviewing branch `feat/x` vs `master` - 4 files, +120/-30").

## What to review

Read the full diff, then read enough of the surrounding source to judge context - do not review lines in isolation. For each changed file, consider:

- **Correctness** - logic errors, off-by-one, null/undefined handling, race conditions, wrong API usage, broken error handling, missed edge cases.
- **Security** - injection (SQL, command, XSS), secrets in code, unsafe deserialization, missing auth checks, unsafe file/path handling, weak crypto.
- **Project-specific rules** - honor any rules in `AGENTS.md` files at the repo root or parent directories. For this dotfiles repo specifically: C# low-level Windows hooks (`LowLevelMouseProc`, `LowLevelKeyboardProc`) must never call `SendInput` synchronously.
- **Consistency** - does the change match surrounding conventions (naming, error handling style, logging, file layout)? Flag only real inconsistencies, not personal preference.
- **Dead / risky code** - unused vars, unreachable branches, swallowed exceptions, TODOs without tickets, debug prints left in, commented-out blocks.
- **Tests** - are behavior changes covered? Are new tests actually asserting something meaningful?
- **Performance** - only flag concrete problems (N+1, unnecessary sync I/O in hot path, accidental O(n^2) on unbounded input). Do not speculate.
- **Memory leaks** - unreleased resources (file handles, sockets, DB connections, native handles), missing `dispose`/`close`/`using`, event listeners or subscriptions added without removal, timers/intervals never cleared, growing caches/maps with no eviction, closures retaining large objects, retained references in long-lived singletons.

## Severity levels

- **Blocker** - will break production, corrupt data, leak secrets, or violate an explicit project rule. Must fix before merge.
- **Major** - real bug or risk but narrower blast radius; strongly recommend fixing.
- **Minor** - small correctness/clarity improvement; author's call.
- **Nit** - optional polish. Group and keep brief.

## Output format

Output should be saved in `.branch-docs/pr-<id>-codex.md`. Chat should output a clickable link to open this file.

```
## Code review - <scope one-liner>

### Blockers
- [path/file.ts:42](../path/file.ts#L42) - <what's wrong, in one sentence>. <Why it matters / suggested fix, one sentence.>

### Major
- ...

### Minor
- ...

### Nits
- ...

<one-line summary: e.g., "2 blockers, 3 major - do not merge yet.">
```

Use clickable markdown links (`[file.ts:42](../file.ts#L42)`) for every location. If a section is empty, write `- (none)` rather than omitting the header.

Note the link path needs to consider that the output will be saved in `.branch-docs/` - adjust the relative path accordingly.

End with the one-line summary. No closing paragraph, no restating what the diff does.

## Rules for the review itself

- Quote the exact symbol or short snippet you're flagging so the author can find it without guessing.
- When suggesting a fix, be concrete (name the function, the flag, the alternative API). Vague advice like "consider refactoring" is not useful.
- If something looks wrong but you're not sure, say so explicitly ("unsure - verify whether X can be null here") instead of either hiding the doubt or escalating the severity.
- Don't invent issues to pad the list. A review with only nits is a fine review.
- Don't repeat the same finding across multiple files - call it out once and list the other locations.
