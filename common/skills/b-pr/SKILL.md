---
name: b-pr
description: Use this skill when the user wants an overview of open pull requests on the current GitHub repo. Triggers include "/b-pr", "/b-pr list", "/b-pr list <user>", "/b-pr review", "/b-pr info <id>", "list my PRs", "show my open PRs", "what PRs does <user> have open", "what PRs are waiting for my review", "status of PR 123", "any new reviews on my PRs", or any phrasing pairing open PRs with their CI / conflict / review status. Default subcommand is `list` — a table of the user's own open PRs (id, title, draft, CI, conflicts, one column per reviewer who posted something). `list <user>` lists another user's open PRs; `review [<user>]` lists PRs where the user's (or another user's) review was requested directly (not via a team), by default only those that are ready (not draft, CI green, no conflicts); `info <id>` shows the same row for one PR plus its latest review comments.
version: 1.0.0
model: haiku
effort: low
allowed-tools:
  - Bash(pwsh:*)
  - PowerShell
---

# PR overview

All data comes from `pr.ps1` next to this file, which wraps `gh` and prints ready-to-show markdown. It runs against the repo of the current working directory, so it needs `gh` authenticated and a GitHub remote.

## Parsing the argument

| Input | Run |
|---|---|
| *(nothing)*, `list` | `pr.ps1 list` |
| `list <user>`, `<user>` (a non-numeric word that is not a subcommand) | `pr.ps1 list <user>` |
| `review` | `pr.ps1 review` |
| `review <user>` | `pr.ps1 review <user>` |
| `review [<user>] --all`, `review [<user>] all` | `pr.ps1 review [<user>] -All` |
| `info <id>`, `<id>` (a bare number, `#123`, or a PR URL) | `pr.ps1 info <id>` |

Strip a leading `#` or `@` and reduce a PR URL to its number. `info` also accepts `-Count <n>` for how many latest comments to show (default 10) — pass it when the user asks for more or fewer ("last 20 comments").

## Steps

1. Run the script from the current working directory (not the skill directory, so `gh` resolves the user's repo):

   ```powershell
   pwsh -NoProfile -File "<skill dir>\pr.ps1" <args>
   ```

2. Print the script output verbatim — it is already a markdown table (plus the comment list for `info`). Do not re-format, re-sort, or drop columns.
3. For `info` only, add at most 2–3 sentences after the output summarizing where the PR stands: what reviewers are asking for that still looks unaddressed, and what is blocking merge (failing checks, conflicts, change requests, draft). Skip the summary if there are no comments and nothing is blocking.
4. If the script fails (not a git repo, no GitHub remote, `gh` not authenticated, PR not found), show the error in one line and stop.

## Review requests

`review` searches `user-review-requested:<user>` (default `@me`), which matches only requests addressed to that user personally — team requests are excluded. GitHub clears a request once that user submits a review, so PRs already reviewed drop off until re-requested.

By default it hides PRs that are not ready to review — draft, conflicting, failing CI, or CI still pending — and prints a `Hidden:` line with a count per reason. PRs whose conflict state is not computed yet (`?`) or that have no checks are shown. `-All` disables the filter. The table adds an **Author** column.

## What the columns mean

- **CI**: `✅` all checks passed/skipped, `⏳ pending` something still running, `❌ n failed` failed/cancelled/timed-out checks, `—` no checks.
- **Conflicts**: GitHub's `mergeable` state — `⚠️ yes` conflicts with the base branch, `no` clean, `?` not computed yet (GitHub computes it lazily; re-running a bit later usually resolves it).
- **Reviewer columns**: one per account that reviewed or commented on any listed PR, excluding the PR's author. The icon is that reviewer's latest decisive state: `✅` approved, `❌` changes requested, `🚫` dismissed, `💬` only comments. A later plain comment does not override an approval or change request (GitHub's own rule). Empty cell = that reviewer has not posted on that PR.
