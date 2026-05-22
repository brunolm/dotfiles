# Environment

- **OS:** Windows 11 Pro
- **Terminal:** PowerShell

# Rules

- Always tailor terminal commands and scripts to the current environment (Windows 11 Pro + PowerShell). Do not suggest Unix/macOS-specific commands or syntax unless explicitly requested.
- Always show a summary and ask permission before:
  - sending emails
  - making changes on the calendar
  - making changes on Linear
  - making changes on Toggl

## Coding

### Style

- use guard clauses to flatten control flow — return early on invalid input, error conditions, and edge cases so the happy path stays at the outermost indentation level. Don't force early returns on short pure functions where a single trailing return is already clear.
- prefer truthy/falsy checks like `if (x)` over verbose comparisons (`if (x === true)`, `if (x !== null && x !== undefined)`). Exception: when `0`, `""`, or `false` are valid values — don't let a falsy zero get treated as missing.
- prefer async/await for sequencing and error handling — use `try`/`catch`/`finally` instead of `.then`/`.catch`/`.finally` chains. `Promise.all` / `Promise.allSettled` are fine, just `await` them. The only acceptable `.catch(...)` is a one-liner fallback like `await x().catch(() => default)`.
- split files along concern boundaries. When a file mixes multiple unrelated responsibilities (e.g., HTTP handling + business logic + data formatting), break them apart. Line count alone isn't a trigger, but a file past ~500 lines is a strong signal to look for a seam.
- extract duplicated code when the repetition has become a maintenance burden — that threshold is a judgment call, not a fixed count. It might be 2 occurrences, or 3+, depending on the size of the block, how related the call sites are, and how likely they are to diverge. When you do extract, place the helper in the nearest shared module or create a file for it depending on its scope. Don't extract structurally similar code that's conceptually unrelated — duplication beats a wrong abstraction.

### Self-review

When you finish a change, sweep your own diff once for:

- unused code
- duplicated code
- comments that should be pruned (see below)
- coding preferences in global config and project config

### Writing comments

Default to no comments. A comment earns its place only when it encodes a *why* the code itself can't show.

Justified cases:

- a hidden constraint or invariant not visible from the signature
- a workaround for a known bug, platform quirk, or external API behavior
- a non-obvious design choice the next reader needs to know before changing it
- a warning about surprising behavior or a tempting-but-wrong refactor
- a reference to an external spec / RFC / standard (name + version)
- public API docs (JSDoc / docstrings) that add real semantic info beyond the signature — units, error conditions, lifetime, idempotency

Don't write:

- narration of what the code does — well-named identifiers do that
- restatements of the function name or signature
- references to the current task / PR / ticket / fix ("fix for #123") — that belongs in the commit message
- references to callers ("used by ComponentX", "called from the auth flow")
- divider banners (`// =====`) or empty JSDoc tags that just restate the signature
- vague TODOs ("// TODO: fix this someday") — give actionable context or skip
- hedging ("maybe", "I think", "not sure if") — commit or omit

### Ordering declarations in a file

Use a newspaper / call-order layout, top to bottom:

1. Imports.
2. Module-level constants and types.
3. The primary export (the entry point a reader wants first), then other exports. If exports call each other, order them by call-order.
4. Internal helpers in **strict call-order** — each helper sits below the function that calls it. When one parent calls several, follow the parent's invocation order.
5. Helpers used by **multiple** parents bubble to the top of the internals block.
6. **Trivial** single-use leaves (tiny comparators, formatters, one-liner predicates) sink to the bottom.
7. **Substantive** single-use leaves stay **adjacent** to their caller — sub-tree locality wins when separating them visibly hurts readability.

When applying the layout:

- Tie-breaker: strict call-order beats sub-tree locality unless the leaf is substantive enough that separating it from its parent visibly hurts.
- When moving a declaration, keep its attached JSDoc / leading comments / decorators with it as one unit.
- Respect hoisting — `function` declarations hoist in JS/TS, but `const` arrow functions and classes don't.
