---
name: brunolm-prune-comments
description: Use this skill when the user asks to review, audit, prune, simplify, or clean up the comments in source files. Triggers include "review comments", "prune comments", "remove unnecessary comments", "simplify comments", "audit comments in changed files", "comment cleanup", or any phrasing that pairs comment hygiene with one or more files. Default scope is the current Git working-tree changes; the user may pass explicit file paths or globs to override.
version: 1.0.0
allowed-tools:
  - Bash(git diff --name-only:*)
  - Bash(git status --short:*)
  - Bash(git ls-files:*)
  - Read
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Prune Comments

Review every comment in the in-scope files, decide whether each comment earns its keep, and propose a tightened version. Apply changes only after the user confirms.

## Comment philosophy applied

The default posture is **no comments**. A comment earns its place only when it encodes information a reader couldn't derive from the code itself — usually a *why*, not a *what*. Specifically:

**Keep** a comment when it:

- Documents a **hidden constraint or invariant** that isn't visible from the signatures.
- Explains a **workaround** for a known bug, platform quirk, or external API behavior.
- Encodes a **non-obvious design choice** the next reader will want to understand before changing it.
- Warns about **surprising behavior** or a tempting refactor that's actually wrong.
- References an **external spec, RFC, or standard** by name/version (and the reference is still relevant).
- Is a **TODO/FIXME** with concrete actionable context — what to do, when, why it's deferred.
- Documents a **public API surface** (exported symbol's JSDoc/docstring) in a way that adds real semantic information beyond the signature — typical inputs, units, error conditions, lifetime, idempotency.

**Simplify** a comment when it:

- Says the right thing in too many lines. Collapse multi-paragraph prose to the one sentence that carries the load.
- Repeats context already visible in a nearby comment.
- Wraps standard boilerplate around one substantive fact — keep the fact, drop the boilerplate.
- Uses JSDoc/docstring tags that restate the signature (`@param x The x parameter`, `@returns the result`). Strip the empty tags; keep only ones with content.
- Hedges (`maybe`, `I think`, `not sure if`) about something the code clearly does. Either commit to the statement or drop it.

**Remove** a comment when it:

- **Narrates the code** ("// loop through items", "// initialize foo", "// set x to 5"). Well-named identifiers do this job.
- **Restates the function name or signature** in prose.
- **References the current task, PR, ticket, fix, or commit** ("fix for #123", "added in PR-456", "per the Linear ticket"). That context belongs in the commit / PR description, not the code — it rots fast.
- **References callers** ("used by ComponentX", "called from the auth flow"). Identifier search finds callers; comments lie when call sites change.
- **Has drifted** — the code it describes no longer matches the comment.
- **Is dead** — commented-out code without a clear, dated reason to keep it.
- **States the obvious** to someone reading the language ("// this is a constructor", "// returns a Promise"). The signature already says that.
- **Is a divider/banner** with no information value (`// ============================================`).
- **Is a TODO/FIXME with no actionable context** ("// TODO: fix this someday"). Either give it real context or delete it.

When a JSDoc / docstring block has a one-sentence useful core surrounded by boilerplate, **simplify** by reducing to that core. Don't delete the whole block; don't keep the chaff.

## 1. Resolve the file set

1. If the user passed one or more arguments, treat each as a file path or glob:
   - Expand globs with `Glob`.
   - Resolve to absolute paths and dedupe.
2. If no arguments were passed, use the current Git working-tree changes:
   - `git diff --name-only HEAD` for staged + unstaged changes against HEAD.
   - Plus untracked files via `git ls-files --others --exclude-standard`.
   - Dedupe and keep only existing files.
3. Filter to source files. Default allow-list of extensions:
   - `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`
   - `.py`
   - `.go`
   - `.rs`
   - `.rb`
   - `.swift`, `.kt`
   - `.java`, `.cs`, `.c`, `.cc`, `.cpp`, `.h`, `.hpp`
   - `.sh`, `.ps1`
   - Skip lockfiles, JSON, YAML, Markdown, CSS, HTML. If a file is excluded, mention it briefly so the user can override.
4. If the resolved set is empty, report that and stop.
5. State the resolved file list back to the user in one short line before continuing.

## 2. For each file, catalogue comments

Read the file once. Identify every comment, where "comment" means:

- Single-line comments (`//`, `#`, `--`)
- Block comments (`/* … */`, `=begin … =end`, `"""…"""` when used as a comment rather than a docstring on a callable)
- JSDoc / docstring blocks (`/** … */` in JS/TS, triple-quoted strings on functions/classes/modules in Python, `///` in Rust/Swift, `///`-style in C#)
- Inline trailing comments on otherwise-code lines

For each comment, capture:

- Its **span** (start line, end line, leading indentation).
- Whether it is **attached** to a following declaration (the next non-blank line is a function/class/const declaration), an **inline** annotation on a code line, or **free-floating** between blocks.
- Its **kind**: `line`, `block`, `jsdoc`/`docstring`, `directive` (e.g. `// eslint-disable-next-line`, `# type: ignore`, `// @ts-expect-error`, shebangs).

**Directive comments are out of scope** — never touch `eslint-disable*`, `@ts-*`, `type: ignore`, `noqa`, shebangs (`#!`), file-encoding declarations, copyright headers, license blocks, or compiler / linter / build-tool pragmas. List them as "preserved" in the summary so the user knows they were noticed.

## 3. Classify each comment

For every non-directive comment, assign one verdict:

- **keep** — meets one of the criteria in the Keep list above. Note which one.
- **simplify** — meets a Simplify criterion. Propose the tightened replacement text in full.
- **remove** — meets a Remove criterion. Note which one.

Edge-case rules:

- A comment that **just repeats the next identifier's name** is `remove`.
- A JSDoc block whose only content is `@param`/`@returns` tags that restate the signature with no extra information is `remove`.
- A JSDoc block with one substantive sentence plus tag boilerplate is `simplify` — keep the sentence, drop the empty tags.
- A workaround comment that names a specific bug/version/library is `keep` unless the workaround is clearly stale.
- When in doubt between `keep` and `simplify`, prefer `simplify`. When in doubt between `simplify` and `remove`, prefer `simplify`.
- **Never speculate** about whether code is correct based on the comment. If you can't reach a clear verdict from the comment + nearby code, classify it `keep` and move on.

## 4. Show the proposed changes

For each file, produce a short summary before touching anything:

- Per-comment lines, one per comment, formatted like:
  - `L<line>  keep      — <one-sentence reason or quoted criterion>`
  - `L<line>  remove    — <criterion that triggered removal>`
  - `L<line>  simplify  — <criterion> → "<proposed replacement text, single line>"`
- For multi-line block / JSDoc proposals, show the proposed replacement as a fenced quoted block under the entry.
- Footer: counts (kept / removed / simplified / preserved directives).

If the user previously picked **Apply all**, skip the question and proceed straight to step 5 for this file (the summary above is still printed so the user can see what was done).

Otherwise, ask via `AskUserQuestion`:

1. **Apply** — perform every proposed change in this file.
2. **Apply all** — perform the proposed changes for this file **and every remaining file in the set without prompting again**. Print each file's summary as you go.
3. **Skip** — leave this file alone, keep prompting for subsequent files.
4. **Show full diff** — print the equivalent before/after for each touched comment and re-ask.

If the user picks **Show full diff**, present each touched comment as a small before/after pair (fenced), then re-ask the original four-option question. Do not apply until the user confirms.

If the user picks **Apply all**, remember that choice for the rest of this skill invocation — every remaining file is applied automatically after its summary is printed.

## 5. Apply the changes

When the user picks **Apply**:

1. Read the file again (in case it changed).
2. Walk the changes from the bottom of the file upward, so earlier edits don't shift later line numbers.
3. For each `remove`: delete the comment lines, including the line break(s) the comment owns, but preserve any code on the same physical line (for trailing inline comments, strip only the comment portion + the leading whitespace before `//` / `#`).
4. For each `simplify`: replace the comment lines with the proposed single-line (or compacted block) replacement. Preserve original indentation.
5. After deletions, do not leave more than one blank line in a row inside a function body. Trim runs of blank lines that the deletions created.
6. Re-read the file once and verify it still parses by quick visual scan (no dangling block-comment openers, no orphan `*/`, no half-deleted JSDoc). If anything looks wrong, revert with a one-line note and move to the next file.

## 6. After every file

Print a final summary:

- Files processed, with counts per verdict.
- Files skipped or reverted, with one-line reason.

Do not commit. The user owns commit boundaries — this skill only edits comments.

## Rules

- **Never change code.** This skill touches only comment text and the whitespace immediately around removed comments. If a comment removal would require restructuring code (e.g., a comment is the only line in a block), keep the comment and report it.
- **Never delete licence headers, copyright notices, shebangs, or directive comments.** When in doubt about whether a top-of-file block is informational or legal, leave it.
- **Never rewrite a comment as a different statement.** Simplifications must preserve the underlying meaning — tightening allowed, paraphrasing into a different claim is not.
- **One file at a time.** Each file gets its own propose → confirm → apply cycle. Do not batch silently.
- **Preserve indentation and blank-line semantics.** A removed comment leaves the file at the same indentation level. Two-line gaps stay two-line; never collapse beyond one.
- **Honor `AskUserQuestion`.** If the user wants to see the diff before accepting, show it.
- **Don't translate.** Keep the original language of any kept or simplified comment. Don't rewrite Portuguese / Japanese / German comments into English.
- **Don't editorialise.** Do not add new comments. This skill is strictly pruning, not authoring.
