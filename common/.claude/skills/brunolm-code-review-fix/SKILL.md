---
name: brunolm-code-review-fix
description: Use this skill when the user wants to work through findings from a saved code review and resolve them one by one. Triggers include "fix the review", "apply the review", "go through review findings", "work the review", "address the review comments", or any phrasing that pairs a review file under `.branch-docs/` with intent to act on it. Walks each finding interactively, fixes/explains/skips per the user's choice, commits each fix as its own commit, and keeps the review file updated as items are resolved.
version: 1.0.0
allowed-tools:
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git log:*)
  - Bash(git push:*)
  - Bash(git rev-parse:*)
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# Code Review Fix

Walk through a saved code review interactively, resolve each finding with the user's approval, and commit progress as you go.

## 1. Locate the review file

1. Build the target path: `.branch-docs/pr-<id>.md`. `<id>` is the argument the user passed; if no argument, use the current local branch name (`git rev-parse --abbrev-ref HEAD`).
2. If that file exists, use it.
3. If it does not exist, list everything under `.branch-docs/` with `Glob`, then narrow to entries that look like code reviews — filenames containing `pr-`, `review`, or matching `*-claude.md` / `*-codex.md` — and peek at the first heading to confirm (real reviews start with `## Code review`). Ask the user which file to use via `AskUserQuestion`.

State the chosen file in one short line before continuing.

## 2. Parse findings

Read the review file. Extract every finding under `### Blockers`, `### Major`, `### Minor`, and `### Nits` in that order (ignore sections that say `- (none)`). Keep the original bullet text verbatim — you will use it to identify the item when rewriting the file later.

## 3. Walk findings one at a time

For each finding, present three things:

1. **The original item** — verbatim, including the file link and severity.
2. **Plain-language explanation** — what the problem actually is, no jargon, 1-2 sentences.
3. **Proposed fix** — the concrete change you would make (which function, which line, which API), 1-2 sentences.

Then ask the user via `AskUserQuestion`:

1. **Fix** — apply the change now.
2. **Explain more** — give a deeper explanation, then re-ask.
3. **Skip** — leave the code alone and mark the item skipped.

### If Fix

1. Read enough surrounding context to make the change correctly, then apply it with `Edit` / `Write`.
2. Show a one-line summary of what changed (file + symbol). Ask via `AskUserQuestion`:
   1. **Fixed — commit it**
   2. **Not quite — more context** (treat the user's reply as additional instructions, revise the fix, then re-ask)
3. On confirmation, commit:
   - Stage only the files touched for this finding (`git add <files>`). Never `git add -A` or `git add .`.
   - Use a focused message: `fix(<scope>): <short summary>`, with a body that names the file/line and one sentence on the underlying issue.
   - Capture the short SHA via `git rev-parse --short HEAD`.
4. Update the review file: remove the bullet from its severity section and append it under a `### Fixed` section as `- <original first sentence> — fixed in <short-sha>`. Create the `### Fixed` section if it does not exist yet.

### If Explain more

Give a deeper explanation — root cause, why it matters, how the proposed fix works, any tradeoffs — then re-ask the original three-option question for the same finding.

### If Skip

Remove the bullet from its severity section and append it under a `### Skipped` section as `- <original first sentence> — skipped`. Create `### Skipped` if needed. Do not commit the review-file change on its own yet; it will ride along with the next code commit, or get its own commit at the end if no more code changes happen.

## 4. After every finding is handled

1. If the review file has uncommitted edits, commit them: `chore(review): update <review-file> after working findings`.
2. Print a summary:
   - Total findings handled.
   - Fixed (with short SHAs).
   - Skipped.
3. Ask the user via `AskUserQuestion`:
   1. **Push** — `git push` to the current branch's upstream (use `-u origin <branch>` if no upstream is set).
   2. **End** — stop here.

## Rules

- One finding at a time. Do not batch fixes silently.
- Never lose a finding. By the end, every original item must appear under `### Fixed` or `### Skipped`.
- Always create new commits — never amend.
- Stage only the files actually touched. Never `-A` or `.`.
- Never push without explicit confirmation in step 4.
- If a fix has to touch files beyond the finding's stated scope (e.g., a shared helper), call that out before committing so the user can veto.
- Honor project rules in `CLAUDE.md` files when applying fixes.
