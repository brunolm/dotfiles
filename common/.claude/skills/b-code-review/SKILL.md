---
name: b-code-review
description: Use this skill when the user asks for a code review, wants feedback on changes, or says things like "review my code", "review this branch", "review this PR", "review the diff", "what do you think of these changes", or "look over my changes". Reviews either the current branch diff, uncommitted working-tree changes, or a specified GitHub PR, and reports findings grouped by severity. Accepts optional `--grok` / `--codex` / `--claude` flags to get a second opinion on the findings from that agent's CLI (default: no secondary agent).
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
  - Bash(mktemp:*)
  - Bash(claude -p:*)
  - Bash(codex exec:*)
  - Bash(grok -p:*)
  - Read
  - Grep
  - Glob
  - Task
---

# Code Review

Perform a focused code review of the user's changes and return findings grouped by severity.

## Scope selection

Pick scope in this order:

1. If the user passes a PR number or URL (`#123`, `https://github.com/.../pull/123`) — review that PR via `gh pr diff <n>` and `gh pr view <n> --json title,body,author,baseRefName,headRefName,additions,deletions,files`.
2. If the user passes a ref (`main`, `HEAD~3`, `abc123..def456`) — diff against that ref.
3. If the working tree has uncommitted changes (`git status --porcelain` non-empty) and the user said "my changes" / "what I'm working on" — review working-tree diff (`git diff HEAD`).
4. Otherwise — review the current branch against its merge-base with the main branch:
   ```bash
   BASE=$(git merge-base HEAD "$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')" 2>/dev/null || git merge-base HEAD master 2>/dev/null || git merge-base HEAD main)
   git diff "$BASE"...HEAD
   ```

State the chosen scope in one line before diving in (e.g., "Reviewing branch `feat/x` vs `master` — 4 files, +120/-30").

## What to review

Read the full diff, then read enough of the surrounding source to judge context - do not review lines in isolation. PRs often hide issues outside the immediate changed hunk, so search and inspect related code if more context is needed to evaluate the changes. Focus the review on the changes, do not review things that are not part of the changes and PR scope.

For each changed file, consider:

- **Correctness** — logic errors, off-by-one, null/undefined handling, race conditions, wrong API usage, broken error handling, missed edge cases.
- **Security** — injection (SQL, command, XSS), secrets in code, unsafe deserialization, missing auth checks, unsafe file/path handling, weak crypto, PII leaks.
- **Project-specific rules** — honor any rules in `CLAUDE.md` files at the repo root or parent directories. For this dotfiles repo specifically: C# low-level Windows hooks (`LowLevelMouseProc`, `LowLevelKeyboardProc`) must never call `SendInput` synchronously.
- **Consistency** — does the change match surrounding conventions (naming, error handling style, logging, file layout)? Flag only real inconsistencies, not personal preference.
- **Dead / risky code** — unused vars, unreachable branches, swallowed exceptions, TODOs without tickets, debug prints left in, commented-out blocks.
- **Tests** — are behavior changes covered? Are new tests actually asserting something meaningful?
- **Performance** — only flag concrete problems (N+1, unnecessary sync I/O in hot path, accidental O(n²) on unbounded input). Do not speculate.
- **Memory leaks** — unreleased resources (file handles, sockets, DB connections, native handles), missing `dispose`/`close`/`using`, event listeners or subscriptions added without removal, timers/intervals never cleared, growing caches/maps with no eviction, closures retaining large objects, retained references in long-lived singletons.

## Review angles

The checklist above is what to look for; the angles below are how to sweep the diff. Run each as its own pass. Intent checks the diff against its stated purpose; Angles A–D hunt for bugs; Reuse, Simplification, Efficiency, and Altitude hunt for cleanup in the changed code.

### Intent

Establish what the PR is supposed to do from whatever context exists — PR title/description, branch name, commit messages, linked issues — then check the diff against that intent in both directions:

- **Promised but missing** — the intent implies changes the diff doesn't deliver: an unhandled case the fix claims to cover, a half-done rename, a feature path left out.
- **Present but unexplained** — the diff contains changes the intent doesn't account for: unrelated edits, drive-by refactors, scope creep.

Flag mismatches in either direction. An unexplained change isn't automatically a defect — raise it as a question for the author unless it's independently wrong.

### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for each hunk — bugs in unchanged lines of a touched function are in scope (the PR re-exposes or fails to fix them). For every line ask: what input, state, timing, or platform makes this line wrong? Look for inverted/wrong conditions, off-by-one, null/undefined deref, missing `await`, falsy-zero checks, wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

### Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it enforced, then search the new code for where that invariant is re-established. If you can't find it, that's a candidate: a removed guard, a dropped error path, a narrowed validation, a deleted test that was covering a real case.

### Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and check whether the change breaks any call site: a new precondition, a changed return shape, a new exception, a timing/ordering dependency. Also check callees: does a parallel change in the same PR make a call unsafe?

### Angle D — blast radius

Angle C traces direct callers; this angle hunts for side effects a symbol search won't surface. For each change, ask what else observes its effects and whether any of those observers break:

- **External contracts** — public APIs, schemas, serialized/wire formats, cache keys, file formats: can old data still be read, and can old readers handle new data (rolling deploys, queued messages, existing files)?
- **Shared state and config** — globals, singletons, env vars, feature flags, tuned constants also read elsewhere; a value adjusted for this change may be load-bearing for another feature.
- **Timing and ordering** — changed initialization order, new async boundaries, widened/narrowed lock scope, events now firing earlier or later than consumers expect.
- **Operational surface** — logs, metrics, alerts, exit codes, error messages that dashboards, monitors, or scripts key on; renaming or removing these breaks them silently.

### Reuse

Flag new code that re-implements something the codebase already has — Grep shared/utility modules and files adjacent to the change, and name the existing helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind. Name the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work added to startup or hot paths. Also flag long-lived objects built from closures or captured environments — they keep the entire enclosing scope alive for the object's lifetime (a memory leak when that scope holds large values); prefer a class/struct that copies only the fields it needs. Name the cheaper alternative.

### Altitude

Check that each change is implemented at the right depth, not as a fragile bandaid. Special cases layered on shared infrastructure are a sign the fix isn't deep enough — prefer generalizing the underlying mechanism over adding special cases.

## Severity levels

- **Blocker** — will break production, corrupt data, leak secrets, or violate an explicit project rule. Must fix before merge.
- **Major** — real bug or risk but narrower blast radius; strongly recommend fixing.
- **Minor** — small correctness/clarity improvement; author's call.
- **Nit** — optional polish. Group and keep brief.

## Confidence pass

After drafting the findings but before writing the output file, rank every item's confidence and enforce the per-severity thresholds.

### Confidence ranks

| Rank | Meaning |
|------|---------|
| **S** | Verified — traced the exact failure path in the code (or the violated rule is explicit); no assumptions left. |
| **A** | Near-certain — the logic is wrong on its face; no plausible reading makes it correct, though the failure wasn't traced end-to-end. |
| **B** | Confident — strong evidence with one unverified assumption (an input shape, caller behavior, or config inferred from convention). |
| **C** | Probable — plausible, but rests on multiple unverified assumptions; surrounding context supports it without confirming it. |
| **D** | Uncertain — the code looks suspicious but no concrete failure scenario could be pinned down. |
| **E** | Speculative — pattern-matching on "this often goes wrong"; no evidence in this specific code. |
| **F** | Unfounded — no articulable failure scenario. |

Classify every finding as exactly one rank. Rank the claim as written — if verifying an assumption would change the rank, verify it (Read/Grep) instead of guessing.

### Per-severity thresholds

| Severity | Deep dive first if | Keep | Drop |
|----------|--------------------|------|------|
| Blocker | C or below | S–B, plus C with the residual doubt stated in the finding | D–F |
| Major | C or below | S–B | C–F |
| Minor | (no dive) | S–B | C–F |
| Nit | (no dive) | S–A | B–F |

- **Deep dive** (Blocker/Major ranked C or below): before deciding, re-read the flagged code and enough surrounding context, trace the relevant callers/callees, inspect related files, and test the assumption that created the doubt — then re-rank from what you found and apply the Keep/Drop columns to the new rank. High-stakes claims are never dropped on the initial rank alone.
- Minor and Nit items are low-stakes: a shaky claim is not worth the author's attention, so they are dropped on their initial rank without a dive.

Re-number the surviving items 1…N (continuous across all sections) after the pass so the final list has no gaps.

## Second opinion (`--grok` / `--codex` / `--claude`)

Default: no secondary agent. When the user passes `--grok`, `--codex`, or `--claude`, get a second opinion from that agent's CLI after the confidence pass and before writing the output file. If more than one flag is passed, run each agent and merge each response separately.

### 1. Build the context file

Create a temp path (`CTX="$(mktemp -d)/review-context.md"`) and write a file there containing everything the agent needs to judge the review without re-deriving it:

- the scope one-liner and PR metadata (title, description, branch, author) when available
- the full diff under review
- the surviving draft findings, numbered, each with file:line, severity, confidence rank, and the one-sentence claim

### 2. Run the agent

From the repo root (so the agent can read surrounding source for context), with a generous command timeout (10 minutes):

```bash
claude -p "<prompt>"     # --claude
codex exec "<prompt>"    # --codex
grok -p "<prompt>"       # --grok
```

Prompt (substitute the real temp path):

```
Second opinion on a code review. Read <CTX path> — it contains the diff under review and the reviewer's draft findings. You may read the repository for extra context. Reply with: (1) for each numbered finding, AGREE / DISAGREE / ADJUST plus one sentence of reasoning; (2) any real issues in the diff the review missed, each as file:line, severity (Blocker/Major/Minor/Nit), and a one-line explanation. Be concrete; do not pad with speculative items.
```

Use this prompt verbatim — only the path varies. Never inline the diff, findings, or any other per-review content into the command-line prompt; long argv breaks on Windows (~32k char limit). Everything sized by the review belongs in the context file.

### 3. Merge the response

- **Agreements** — no change to the finding.
- **Disagreements / adjustments** — re-check the disputed claim yourself; if the agent is right, drop or re-rank the finding as in the confidence pass, otherwise keep it. Either way append a sub-bullet to the finding: `**second opinion (<agent>):** <verdict and resolution in one line>`.
- **New issues** — verify and confidence-rank each one exactly like your own findings; those that survive the per-severity thresholds join the numbered list with `(raised by <agent>)` at the end of the claim. Silently drop the rest.
- Re-number after merging, then fill in the `### Second opinion` section of the output (see template).
- If the CLI fails or is not installed, say so in chat and finish the normal review without it.
- Delete the temp folder after merging.

## Output format

Output should be saved in `.branch-docs/pr-<id>-claude.md`, if the file already exists then overwrite it. If a PR hasn't been specified use the current branch name as `<id>`.

Chat should output a clickable link to open this file.

```
## Code review — <scope one-liner>

- Author: `<author login>` (`<author name>`)
- Branch: `<headRefName>` (vs `<baseRefName>`)

### Blockers
1. [path/file.ts:42](../path/file.ts#L42) — <what's wrong, in one sentence>. <Why it matters / suggested fix, one sentence.> (confidence: <S|A|B|C>)
   - **tl;dr (problem):** <the claim problem boiled down to one short line>
   - **tl;dr (fix):** <the claim suggested fix boiled down to one short line>

### Major
2. ...
   - **tl;dr (problem):** ...
   - **tl;dr (fix):** ...

### Minor
3. ...
   - **tl;dr (problem):** ...
   - **tl;dr (fix):** ...

### Nits
4. ...
   - **tl;dr (problem):** ...
   - **tl;dr (fix):** ...

### Second opinion — <agent>
- Agrees with: <finding numbers, or "(none)">
- Disputed: <finding number> — <resolution in one line>
- Raised: <numbers of findings it added, or "(none)">

<one-line summary: e.g., "2 blockers, 3 major — do not merge yet.">
```

Omit the `### Second opinion` section entirely when no secondary agent flag was passed; repeat it per agent when several were.

Number every item continuously across all sections (1…N) so each finding can be referenced by its number; do not restart numbering per section. End every item with two sub-bullets: `**tl;dr (problem):**` boiling the problem down to one short line, and `**tl;dr (fix):**` boiling the suggested fix down to one short line.

Use clickable markdown links (`[file.ts:42](../file.ts#L42)`) for every location. If a section is empty, write `- (none)` rather than omitting the header.

Note the link path needs to consider that the output will be saved in `.branch-docs/` — adjust the relative path accordingly.

End with the one-line summary. No closing paragraph, no restating what the diff does.

## Rules for the review itself

- Quote the exact symbol or short snippet you're flagging so the author can find it without guessing.
- When suggesting a fix, be concrete (name the function, the flag, the alternative API). Vague advice like "consider refactoring" is not useful.
- If something looks wrong but you're not sure, say so explicitly ("unsure — verify whether X can be null here") instead of either hiding the doubt or escalating the severity.
- Don't invent issues to pad the list. A review with only nits is a fine review.
- Don't repeat the same finding across multiple files — call it out once and list the other locations.
