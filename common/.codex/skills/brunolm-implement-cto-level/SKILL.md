---
name: brunolm-implement-cto-level
description: Use this skill when the user wants something implemented to the highest engineering standard — not a quick patch, but the most robust, well-architected version that fits the existing codebase. Triggers include "implement this CTO-level", "build this properly", "do this the right way", "production-grade implementation of X", "architect and implement X", or any request to implement a feature where the user signals they want maximum quality, reuse, and architectural fit rather than the fastest path. Takes the thing to build as input, plans deeply first, then implements.
version: 1.0.0
allowed-tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# Implement (CTO-level)

Implement the requested thing at the standard a principal engineer / CTO would accept: the most robust, organized, and maintainable version that fits the codebase as it already exists. **Plan before writing code.** The quality bar is set in the design phase — implementation is just faithful execution of a good plan.

The input is the thing to build (a feature, refactor, module, integration, fix). If no input was given, ask what to implement before doing anything else.

## The bar

Every decision is judged against these. When a shortcut conflicts with one of these, the shortcut loses.

- **Fit over invention** — match the existing structure, architecture, naming, and idioms. New code should look like it was always there.
- **Reuse over duplication** — find and use what already exists (functions, utilities, types, packages, patterns) before writing new code or adding dependencies. Duplication is a defect unless a wrong abstraction is the only alternative.
- **Single responsibility** — each module/function/type does one thing. Split along concern boundaries (HTTP vs. business logic vs. data access vs. formatting).
- **Smallest correct surface** — the least new public API, the fewest new files, the narrowest types that still model the domain honestly. No speculative generality.
- **Robust by construction** — handle the edge cases, the errors, the empty/null/zero, the concurrent and the partial. Make illegal states unrepresentable where the language allows.
- **Honest trade-offs** — there is no "perfect"; there is the right call for this codebase, stated with its cost.

Also enforce the user's coding standards from CLAUDE.md (guard clauses / early returns, truthy-falsy checks, async/await over `.then` chains, concern-boundary file splits, newspaper/call-order declaration layout, comment discipline — a comment must encode a *why*). These are non-negotiable, not stylistic preferences.

## Phase 0 — Intake & scoping

1. Restate the request in one line so the user can catch a misread early.
2. Clarify only what blocks the design — requirements and constraints, never implementation details you can decide yourself. Ask via `AskUserQuestion` only if a wrong assumption would force a rewrite. Examples worth asking: a missing acceptance criterion, an unstated scale/perf target, an unclear boundary ("should this also handle X?"). Do **not** ask which pattern/library to use when the codebase already answers that — discover it in Phase 1.
3. If the request is genuinely large, name the smallest end-to-end slice that delivers value, and confirm whether to build that slice or the whole thing.

## Phase 1 — Reconnaissance (read-only)

Understand the ground before designing on it. **Write nothing in this phase.** Scale the effort to the task — a one-file change needs a quick look; a new subsystem needs a real survey.

Map, with evidence (file paths, symbols):

- **Structure** — where things live, module boundaries, how the project is laid out, where this change belongs (the right seam).
- **Architecture** — the patterns in force (layering, DI, event flow, error-handling strategy, state management). What's the grain of this codebase?
- **Packages** — the dependency manifest and what's already available. Prefer an installed capability over a new dependency. If a new dep seems needed, note it as a decision for the plan, not a fait accompli.
- **Reusable code** — existing functions, helpers, types, hooks, base classes, test utilities that this work should build on instead of re-deriving. This is the most important output of this phase: the reuse map.
- **Conventions** — naming, file organization, test layout/framework, lint/format rules, how errors and logging are done. Match these exactly.
- **Verification surface** — how this project builds, type-checks, lints, and tests. Capture the exact commands for Phase 5.

For anything beyond a small change, fan out with `Explore` agents (and/or a `Plan` agent) to survey in parallel and keep the main context lean — e.g. one agent maps structure/architecture, one hunts reusable code and conventions, one finds the verification commands. Wait for their conclusions; don't also run the same searches yourself.

## Phase 2 — Design

Synthesize recon into a concrete plan. This is where the CTO-level quality is decided. Produce:

1. **Approach** — the chosen design in a few sentences, and *why* it fits this codebase.
2. **Alternatives considered** — at least one other approach and the reason it lost (the trade-off). If the choice is obvious, one line is fine; don't manufacture false options.
3. **Reuse map** — concretely, which existing functions/types/modules/packages this will use, by name and path. Call out anything you considered building that already exists.
4. **New components** — each new file/function/type, its single responsibility, where it lives, and how it connects. Keep this list as small as correctness allows.
5. **Contracts & data flow** — the key signatures/types, inputs→outputs, and how data moves across the boundaries. Make the types model the domain honestly.
6. **Edge cases & failure modes** — what can go wrong (empty, null/zero, oversized, concurrent, network failure, partial write) and how each is handled.
7. **Testing strategy** — what to test, at what level, using the project's existing test setup.
8. **Risks & migration** — anything that touches existing behavior, needs a migration, or could break callers. Note blast radius.

If two designs are genuinely close, you may briefly present both and let the user pick via `AskUserQuestion` — but lead with a recommendation, don't just enumerate.

## Phase 3 — Approval gate

Present the Phase 2 plan to the user and **get a go-ahead before writing code**. (In Claude Code, if you're already in plan mode, surface it via `ExitPlanMode`; otherwise present the plan as text and confirm.) Keep the plan tight and skimmable — bullets and short signatures, not prose walls.

Do not start implementing until the user approves. If they amend the plan, fold the changes in and re-confirm the delta.

## Phase 4 — Implementation

Execute the approved plan faithfully.

- Build in the order that keeps the tree coherent — types/contracts first, then the units that depend on them, then the wiring.
- Match surrounding code in every visible way: imports style, error handling, naming, file layout, comment density.
- Honor every item in **The bar** and the CLAUDE.md standards as you write, not as a cleanup afterthought.
- If implementation reveals the plan was wrong (a reuse target doesn't fit, an edge case explodes scope), stop and surface it — don't silently diverge into a worse design or silently expand scope. A small, obvious correction can proceed; a structural change goes back to the user.
- Don't add features, config, or abstraction the plan didn't call for. Smallest correct surface.

## Phase 5 — Self-review & verification

Before declaring done, sweep your own diff and prove it works.

1. **Self-review the diff** against The bar and CLAUDE.md: unused code, duplicated code, comments that don't earn their place, SRP violations, naming, declaration ordering. Fix what you find.
2. **Verify** with the project's own tooling discovered in Phase 1 — build, type-check, lint, and run the relevant tests. Run them; don't assume. If a command isn't obvious and can't be inferred, ask rather than skip.
3. **Report honestly** — if something fails, say so with the output. If a step was skipped (no test setup, etc.), say that. State what's done and verified plainly, without hedging.
4. Summarize: what was built, the key design decisions and their trade-offs, what's reused, what's new, and any follow-ups or known limitations.

Do not commit unless the user asks — they own commit boundaries.

## Rules

- **Plan first, always.** Never jump to code on a non-trivial request. The plan is the deliverable that earns the "CTO-level" label.
- **Reuse is mandatory, not optional.** If you wrote something the codebase already had, that's a defect to fix in self-review.
- **No new dependency without justification.** Adding a package is a plan-level decision the user sees, not a silent `install`.
- **Scale the ceremony to the task.** A trivial change doesn't need a five-agent survey — but it still gets fit, reuse, and a clean diff. Don't perform process for its own sake.
- **Surface, don't swallow.** When the plan meets reality and they disagree, tell the user. Quiet divergence is how robust plans become mediocre code.
- **Honesty over polish.** Report failures, skips, and uncertainty straight. A working-but-honest result beats a confident-but-wrong one.
