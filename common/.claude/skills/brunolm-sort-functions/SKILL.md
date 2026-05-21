---
name: brunolm-sort-functions
description: Use this skill when the user asks to sort, reorder, or reorganize the functions and helpers inside source files using the newspaper / call-order convention. Triggers include "sort this file", "sort functions in changed files", "reorder helpers", "apply newspaper layout", "fix function ordering", or any phrasing that pairs reordering with one or more files. Default scope is the current Git working-tree changes; the user may pass explicit file paths or globs to override.
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

# Sort Functions

Reorder top-level declarations inside source files to follow a strict call-order / newspaper layout, without changing behavior.

## Convention applied

The ordering this skill enforces, from top of file to bottom:

1. **Imports** — left as-is.
2. **Module-level constants and types** — grouped together at the top, in their existing order unless the user asks otherwise.
3. **The primary export** — the function or symbol that is the entry point a reader of this module wants to find first. If a file has only one export, that's the primary. If multiple, the primary is the one called by the rest, or (when they're peer-level) the one whose name most matches the module name.
4. **Other exports** — in roughly call-order if they relate; otherwise in their existing order.
5. **Internal helpers** — in **strict call-order**: each helper appears below the function that calls it. When two helpers are both called by the same parent, place them in the order the parent's body invokes them.
6. **Universally-shared leaves** — internal helpers used by multiple exports/parents bubble to the **top** of the internals block (right after the last export). They behave like a shared utility for everything below.
7. **Trivial leaves** — single-use leaves that are tiny (comparators, formatters, one-liner predicates) collect at the **bottom**. The reader rarely needs to find them.
8. **Substantive single-use leaves** — when a leaf is large or its name doesn't fully explain it, keep it **adjacent to its caller** (sub-tree locality) instead of pushing it to the bottom.

The default tie-breaker between "strict call-order" and "sub-tree locality" is **strict call-order**. Only switch to sub-tree locality when the leaf is substantive enough that splitting it from the parent visibly hurts readability — flag that explicitly when you do it.

## 1. Resolve the file set

1. If the user passed one or more arguments, treat each as a file path or glob:
   - Expand globs with `Glob`.
   - Resolve to absolute paths and dedupe.
2. If no arguments were passed, use the current Git working-tree changes:
   - `git diff --name-only HEAD` for staged + unstaged changes against HEAD.
   - Plus untracked files via `git ls-files --others --exclude-standard`.
   - Dedupe and keep only existing files.
3. Filter to source files by extension. Default allow-list:
   - `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`
   - `.py`
   - `.go`
   - `.rs`
   - `.rb`
   - `.swift`, `.kt`
   - Skip anything else (lockfiles, json, markdown, css, etc.). If a file is excluded, mention it briefly in the summary so the user can override.
4. If the resolved set is empty, report that and stop.
5. State the resolved file list back to the user in one short line before continuing.

## 2. For each file, analyze top-level declarations

Read the file once. Identify each **top-level declaration** — anything declared directly at the module level. For each one, capture:

- Its **kind**: `import`, `type`, `constant`, `function`, `class`, `export`.
- Its **name**.
- Its **span** (start line, end line) so it can be moved as a single unit without splitting attached JSDoc / comments / decorators.
- Its **export status**: whether it is publicly exported from the module.
- Its **outgoing calls**: names of other top-level declarations it references. Build this by scanning the declaration body for identifiers that match other top-level names. References inside strings, comments, or nested type-only positions don't count.
- Whether it is a **trivial leaf** — a function under ~10 lines that calls nothing else top-level (comparator, formatter, predicate). Otherwise it is **substantive**.

Adjacent JSDoc / leading comment blocks and decorators are part of the declaration's span — never separate them.

## 3. Compute the target order

For the set of non-import declarations, derive a new ordering using the convention above:

1. Constants and types first, in their current order.
2. Exports next. If exports have a call relationship, sort them in call-order. Otherwise preserve their current order.
3. Internal helpers below the exports. Walk the call graph from the exports:
   - A helper used by **multiple** parents (different exports, or different unrelated callers) → place it at the top of the internals block.
   - A helper used by exactly **one** parent → place it directly after that parent, in the order that parent's body calls it.
   - When a single-use leaf is **trivial**, sink it toward the bottom of the internals block rather than placing it adjacent. Note this choice in the proposed-change summary so the user can override.
4. If two valid placements exist for the same helper, prefer **strict call-order** (caller body order) over **sub-tree locality**.

If the call graph has cycles, place the cycle members in their current relative order and call this out.

If a file has zero internal helpers (everything is exported), the convention reduces to "exports in call-order" — apply that and move on.

## 4. Show the proposed change

For each file, produce a short summary before touching anything:

- The current top-down order of declarations (names only, one per line, with `(export)` markers).
- The proposed top-down order, same format, with `→` arrows next to items that moved.
- For each move, one sentence on **why** (e.g., "called by `installLoaderPatch`, body position 2"; "leaf used by all three exports, hoisted").

If the user previously picked **Apply all**, skip the question and proceed straight to step 5 for this file (the summary above is still printed so the user can see what was done).

Otherwise, ask via `AskUserQuestion`:

1. **Apply** — perform the reorder for this file.
2. **Apply all** — perform the reorder for this file **and every remaining file in the set without prompting again**. Print each file's summary as you go.
3. **Skip** — leave this file alone, keep prompting for subsequent files.
4. **Show full diff** — print the would-be diff and re-ask.

If the user picks **Show full diff**, generate the diff in your head from the moves (no need to write a real patch file) and present it as fenced code, then re-ask the original four-option question.

If the user picks **Apply all**, remember that choice for the rest of this skill invocation — every remaining file is applied automatically after its summary is printed.

## 5. Apply the reorder

When the user picks **Apply**:

1. Read the file again (in case it changed).
2. Splice each declaration's span out and re-insert in the target order. Preserve every byte that isn't part of a moved span — imports, blank-line separators between sections, header comments, decorators, attached JSDoc. Use `Edit` with carefully scoped `old_string` / `new_string` pairs, or rewrite with `Write` if every line changed.
3. Confirm by re-reading the file once and listing the new order in one short summary line.

If applying produces a file that breaks an obvious invariant (e.g., a `const` references another `const` declared lower in the file and `const`s are not hoisted), revert the change and report the conflict. The user gets the final call.

## 6. After every file

Print a final summary:

- Files processed (Applied / Skipped).
- Files that reported conflicts and were left as-is.

Do not commit. The user owns commit boundaries — this skill only reorders.

## Rules

- **Never change behavior.** Reorder declarations only. Do not rename, refactor, fold, split, or inline anything.
- **Never touch declaration bodies.** A move includes the body verbatim — same characters in, same characters out, modulo position.
- **Imports stay put.** Don't try to sort imports here.
- **One file at a time, in order.** Do not batch silently. Each file gets its own propose → confirm → apply cycle.
- **Honor `AskUserQuestion`.** If the user wants to see the diff before accepting, show it.
- **Hoisting matters.** JavaScript/TypeScript hoist `function` declarations but not `const` arrow functions, classes, or top-level statements. Before moving an arrow-const or class above its references, verify it doesn't break temporal-dead-zone semantics. Python / Go / Rust have their own rules; when in doubt, leave forward references in their current relative order.
- **Stop on ambiguity.** If you can't determine a clear primary export or the call graph is mostly cyclic, present the file's current order, your best-effort proposal, and ask via `AskUserQuestion` whether to apply, skip, or accept an alternative the user proposes.
