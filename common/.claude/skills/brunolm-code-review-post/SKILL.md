---
name: brunolm-code-review-post
description: Use this skill when the user wants to publish a code review to a GitHub PR as a real PR review with inline comments. Triggers include "/brunolm-code-review-post", "post the review", "submit the review to the PR", "publish the review on PR 123", "post the review as approve / request changes", or any phrasing that pairs an existing review (a file under `.branch-docs/` or a review produced earlier in the conversation) with posting it to GitHub. Reads the review, maps each finding to a diff line, and submits a single PR review (comment by default, or approve / request changes if told) whose body is a very short summary plus a tl;dr list, with one inline comment per finding. Supports skipping items ("skip 5", "post 1-3 and 7-9").
version: 1.0.0
allowed-tools:
  - Bash(git rev-parse:*)
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr list:*)
  - Bash(gh api:*)
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# Code Review Post

Take an existing code review and submit it to a GitHub PR as one review: a short top-level body plus one inline comment per finding.

## 1. Resolve the PR

Pick the PR in this order:

1. A PR number or URL the user passed (`#123`, `123`, `https://github.com/.../pull/123`).
2. A PR already identified earlier in the conversation.
3. The PR for the current branch: `gh pr view --json number,url,title,headRefName,baseRefName,isDraft,author`.

If none resolves, stop and ask the user which PR to post to. State the chosen PR in one line (`Posting to PR #123 — <title>`).

## 2. Locate the review

Pick the review source in this order:

1. A review file path the user passed explicitly.
2. A review produced earlier in this conversation (e.g., the user just ran `/brunolm-code-review`) — use its findings directly.
3. `.branch-docs/pr-<id>-claude.md`, where `<id>` is the PR number; if missing, retry with the current branch name (`git rev-parse --abbrev-ref HEAD`).
4. Otherwise, `Glob` `.branch-docs/`, narrow to review-looking files (`pr-*`, `*review*`, `*-claude.md` / `*-codex.md`, first heading `## Code review`), and ask the user which to use via `AskUserQuestion`.

## 3. Parse findings and apply the item filter

Extract every finding in order: number, severity section, file path + line, full finding text, and its `**tl;dr:**` line. Skip placeholder lines like `- (none)` and items already sitting under `### Fixed` / `### Skipped`.

If the user gave an item filter, apply it against the review's own numbering:

- "skip 5" / "skip 2 and 6" — post everything except those numbers.
- "post 1-3 and 7-9" / "only 4" — post exactly those numbers.
- Ranges are inclusive; a number that doesn't exist in the review is reported and ignored.

Default is to post every finding.

## 4. Determine the review event

- Default: `COMMENT`.
- User said approve / LGTM: `APPROVE`.
- User said request changes / block / reject: `REQUEST_CHANGES`.

Note: GitHub rejects `APPROVE` and `REQUEST_CHANGES` on your own PR. If the PR author is the authenticated `gh` user and the event is not `COMMENT`, warn and confirm before attempting (it will fail server-side).

## 5. Anchor findings to the diff

Fetch the diff with `gh pr diff <n>`. Inline review comments can only anchor to lines that appear in the diff hunks.

For each finding:

- If its file + line falls inside a diff hunk on the new side, anchor with `path`, `line`, `side: RIGHT`.
- If it references a deleted line, anchor with `side: LEFT`.
- If the line is not part of any hunk (context drifted, or the finding points outside the changed ranges), do not guess a nearby line — move that finding into the review body under a `**Not anchorable inline:**` list, keeping its text and tl;dr.

## 6. Compose the review

**Top-level body** — keep it short:

```
<1–2 sentence summary of the review outcome, e.g. "2 majors around session handling; the rest is polish.">

**tl;dr:**
1. `path/file.ts:42` — <tl;dr line of finding 1>
3. `path/other.ts:10` — <tl;dr line of finding 3>

**Not anchorable inline:** (only if any)
5. `path/file.ts:120` — <full finding text> — **tl;dr:** <tl;dr line>
```

Keep the review's original numbering (gaps from skipped items are fine — they match the review file).

**Each inline comment**:

```
**<Severity> #<n>:** <finding text — the sentence(s) from the review, without the markdown link wrapper>

**tl;dr:** <tl;dr line>
```

## 7. Confirm, then submit

1. Show the user: target PR, event, count of inline comments, count of body-only items, list of skipped numbers, and the top-level body. Ask via `AskUserQuestion`: **Post it** / **Change event** / **Cancel**. Never post without this confirmation.
2. Write the payload as JSON to a temp file (`Write`, in the scratchpad directory) to avoid shell-quoting issues:

   ```json
   {
     "body": "<top-level body>",
     "event": "COMMENT",
     "comments": [
       { "path": "src/file.ts", "line": 42, "side": "RIGHT", "body": "<inline comment body>" }
     ]
   }
   ```

3. Submit in one call:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<n>/reviews --method POST --input <payload.json>
   ```

4. If the API rejects an inline comment anchor (`422` naming a position/line), remove that comment from the payload, fold the finding into the body's `**Not anchorable inline:**` list, and retry once. If a pending (unsubmitted) review already exists for the user, report it — GitHub allows only one pending review at a time — and ask whether to submit without inline handling or stop.
5. On success, print the review URL from the response (`html_url`).

## Rules

- One review submission total — never post findings as separate standalone PR comments.
- Post findings verbatim from the review; do not soften, rewrite, or re-judge them.
- Never invent anchors: a finding that doesn't map cleanly to a diff line goes in the body, not on a guessed line.
- Respect the item filter exactly; report any filtered numbers that don't exist.
- Never submit without the step 7 confirmation.
