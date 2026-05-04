---
name: brunolm-find-prs-to-review
description: Use this skill when the user asks to find PRs to review, list open PRs needing their attention, show pending code reviews, find review requests, or phrases like "what do I need to review", "pending reviews", "PRs waiting on me", "review queue". Uses the GitHub CLI to list open PRs from the current repository, excluding the user's own PRs, drafts, and PRs they have already commented on or reviewed, prioritizing those where their review was explicitly requested.
version: 1.0.0
allowed-tools:
  - Bash(gh pr list:*)
  - Bash(gh repo view:*)
  - Bash(gh search prs:*)
---

# Find PRs to Review

Find open pull requests that the user should review in the current repository.

## Filter criteria

Include PRs that match ALL of:

- Open (not closed or merged)
- Not draft
- Not authored by the user
- Not yet commented on by the user
- Not yet reviewed by the user

## Output ordering

Split the results into two sections, in this order:

1. **Review requested** - PRs where the user (or a team they're on) is in the requested reviewers list.
2. **Other open PRs** - remaining PRs matching the criteria where the user is not a requested reviewer.

Within each section, sort by most-recently updated first.

## How to fetch

Always scope to the current repository. `gh pr list` defaults to the current repo when run inside a git checkout, so do not pass `--repo`. Use `@me` so the logged-in GitHub user is resolved automatically - do not hardcode a username.

Run these two searches in parallel:

**1. Review requested (priority):**

```bash
gh pr list \
  --state open \
  --draft=false \
  --search "review-requested:@me -author:@me -commenter:@me -reviewed-by:@me" \
  --json number,title,author,url,updatedAt,isDraft,reviewRequests,headRefName \
  --limit 50
```

**2. Everything else (not authored by me, no comment/review from me, not a draft):**

```bash
gh pr list \
  --state open \
  --draft=false \
  --search "-author:@me -commenter:@me -reviewed-by:@me -review-requested:@me" \
  --json number,title,author,url,updatedAt,isDraft,reviewRequests,headRefName \
  --limit 50
```

Notes:

- `--search` uses GitHub's search qualifiers; the leading `-` negates them.
- `-commenter:@me` covers issue-level comments. `-reviewed-by:@me` covers PRs with any review (approve/changes-requested/commented review). Using both together catches PRs the user has already engaged with.
- If either command errors out (e.g., `gh` not authenticated), report the error and stop - do not fall back to unfiltered output.

## How to present

For each PR, show one line:

```
#<number> <branch> <title> - @<author> (updated <relative time>) <url>
```

Use a compact markdown list under each section header. If a section is empty, say "(none)" under it rather than omitting the header.

At the end, print a one-line total count (e.g., `5 review-requested, 12 other`). No summary paragraph.

## Optional arguments

If the user passes arguments to the skill, respect them:

- `--repo <owner/name>` - pass through to `gh pr list --repo <owner/name>` to override the current repo.
- `--all-repos` - search across all repos the user has access to. Replace the `gh pr list` calls with `gh search prs` equivalents:
  ```bash
  gh search prs --state=open --draft=false \
    --review-requested=@me -- "-author:@me -commenter:@me -reviewed-by:@me"
  ```
  and the non-requested variant without `--review-requested=@me` (add `-review-requested:@me` to the trailing search string instead).
- `--limit <n>` - pass through to `gh`'s `--limit`.

Otherwise default to the current repository.
