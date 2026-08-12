# Read-Only Evaluation of the Generated Projects

Each subfolder of this directory (named `<model>-<effort>`) contains one model's attempt at implementing `plan.md`. Evaluate every project against the same rubric, compare the decisions the models made, and write the results to `ai-benchmark.md` in this directory.

## Hard rules

- **Read-only.** Never modify, create, or delete any file inside a project folder. No formatting, no fixes, no "small corrections".
- **Never execute project code.** No `npm install` / `start` / `build` / `test`, no running project files with node, no browser automation (patchright or otherwise), no HTTP requests against a running app. The verdict comes from reading the code.
- Allowed: listing directories, reading files, and read-only git commands (`git log`, `git show`, `git diff`) if a project has a repo.
- Skip `node_modules/` and build output — only confirm whether they exist.

## Procedure (per project)

1. Inventory the file tree (excluding `node_modules/`) to see the structure the model chose.
2. Read `package.json` (dependencies chosen, scripts), then the entry points, then every source file.
3. Map each requirement in `plan.md` to where it is implemented. Record missing and partially implemented features.
4. Trace the core logic by hand, hunting for real bugs:
   - conversion math — rate direction (multiply vs divide, base vs quote currency), rounding, mixed-currency totals
   - date handling — timezone drift on `YYYY-MM-DD` parsing, date comparisons in filters, "days so far" math
   - persistence — serialization round-trips (dates and numbers through JSON), missing fields on reload, corrupt-data handling
   - async — race conditions on rapid navigation/edits, stale responses overwriting fresh state, unhandled rejections
   - state — stale closures, lost updates, derived data that can desync from its source
5. Record the notable decisions: state management approach, API layer shape and rate caching (especially historical per-date rates), persistence format, routing, form handling, styling. For each, judge whether it fits the size of the problem — under- and over-engineering are both demerits.
6. Read the project's `READY-summary-*.md` in this directory and check its claims against the code. Note anything claimed but absent or misrepresented.

## Rubric

Score each dimension 0–10. Weighted total = Σ (score × weight) / 10, giving 0–100.

| Dimension | Weight | What it measures |
|---|---|---|
| Completeness | 15 | Every `plan.md` requirement present and wired up, not just scaffolded |
| Correctness | 20 | Traced logic is right: conversion, aggregation, filters, dates, persistence round-trips |
| Architecture & decisions | 15 | Structure, separation of concerns, and whether each decision fits the problem's scale |
| TypeScript quality | 10 | Domain modeling, soundness — `any`/casts/non-null assertions used as escape hatches count against |
| Robustness | 15 | API failure, loading/empty states, invalid input, edge cases (no expenses, zero budget, unknown currency) |
| Code quality & readability | 10 | Naming, duplication, dead code, component size, comment discipline |
| Performance | 5 | Fetch storms, per-render API calls, uncached repeated rate lookups, wasteful re-renders |
| Security & data safety | 5 | XSS vectors, unescaped interpolation into URLs, unsafe parsing of stored data |
| Testing | 5 | Tests that exist and assert something meaningful (the plan never asked — initiative counts) |

Anchors: 9–10 exemplary · 7–8 solid with minor issues · 5–6 works but notable gaps · 3–4 serious problems · 0–2 broken or absent.

## Fairness

- Apply the identical checks to every project; if a bug hunt is run on one, run it on all.
- Cite `file:line` for every major claim — bugs, missing features, and praise alike.
- Separate objective defects from taste. Style preferences are not findings.

## Report format — `ai-benchmark.md`

Write it in this directory, in this order (conclusion and scores at the top):

1. `# AI Benchmark — <date>`
2. `## Conclusion` — final ranking, the winner and why, and a short verdict paragraph per model.
3. `## Final scores` — one table, ranked by weighted total: model × every rubric dimension + total.
4. `## Methodology` — models and efforts run, wall-clock per model if known, any failures or timeouts.
5. `## Head-to-head decisions` — for each point where models diverged (state management, historical-rate caching, persistence design, form validation, error handling), what each chose and which choice served the problem best.
6. One `## <model>-<effort>` section per project — feature coverage, per-dimension notes with citations, bugs found, strengths, and READY-summary claims vs reality.
