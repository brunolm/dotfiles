---
name: b-test-ai
description: Use this skill when the user wants to benchmark AI coding models against each other by having each build the same app and then scoring the results. Triggers include "/b-test-ai", "benchmark these models", "test ai models", "compare opus vs fable on a real project", or any phrasing pairing multiple AI models/CLIs with building and evaluating the same project. Arguments are a comma-separated list of models, each with optional effort in parentheses — e.g. "opus(medium), fable, grok 4.6" (default effort high). Each model implements the bundled plan.md unattended in its own temp workspace via its CLI; completion is detected through READY-summary files; then every project is evaluated read-only per the bundled read-only-evaluation.md and scored into an ai-benchmark.md report.
version: 1.0.0
---

# Benchmark AI Models

Run the same app-building task through several AI CLIs in parallel, wait for all of them, then evaluate the code each produced — read-only — and write a scored comparison report.

Two files bundled next to this SKILL.md drive the run and must be used as-is (identical spec every run keeps benchmarks comparable across time):

- `plan.md` — the app the models build. Never reveal to a builder that it will be evaluated, and never add quality/best-practice hints to the plan or the prompt.
- `read-only-evaluation.md` — the rubric, rules, and report format for the evaluation phase.

## 1. Parse the arguments

- Split on commas. Each entry is `<model>` or `<model>(<effort>)`; effort defaults to `high`.
- Normalize the model name: trim, lowercase, internal spaces → `-` (`grok 4.6` → `grok-4.6`).
- Slug per run = `<model>-<effort>` (e.g. `opus-medium`, `grok-4.6-high`) — used for the subfolder and the READY file.
- No models given → ask the user which to run.

## 2. Route each model to its CLI

| Model name | CLI command (run from inside the model's subfolder) |
|---|---|
| `fable`, `opus`, `sonnet`, `haiku`, `claude-*` | `claude -p --dangerously-skip-permissions --model <model> --effort <effort> "<prompt>"` |
| `gpt-*`, `o3*`/`o4*`, or bare `codex` | `codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -m <model> -c model_reasoning_effort=<effort> "<prompt>"` (bare `codex`: omit `-m`) |
| `grok*` | `grok -p "<prompt>" -m <model> --reasoning-effort <effort> --always-approve` |

- `--skip-git-repo-check` is required for codex — the temp folder is not a trusted directory.
- Effort passes through verbatim; if a CLI rejects the value (e.g. codex has no `xhigh`), retry with the nearest supported level and note the substitution in the report.
- Unrecognized model name → ask the user which CLI serves it.

## 3. Set up the arena

Create a timestamped folder under the system temp directory and copy the two bundled files into it, then one empty subfolder per slug:

```bash
ROOT="${TMP:-/tmp}/ai-benchmark-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ROOT"
cp "<this skill's folder>/plan.md" "<this skill's folder>/read-only-evaluation.md" "$ROOT/"
mkdir "$ROOT/<slug>"   # one per model
```

Tell the user the arena path before launching.

## 4. Launch the builders

Launch every model **concurrently**, each as a background task, each running from inside its own subfolder. The prompt is identical for all models except the slug:

```
Read the file ../plan.md and implement it completely in the current directory. Do not use the patchright MCP or any other browser automation. Work autonomously and do not ask questions. When the implementation is finished, write a file ../READY-summary-<slug>.md with a short summary of what you built and how it is organized.
```

Nothing else goes in the prompt — no mention of evaluation, comparison, other models, or quality expectations.

## 5. Monitor

- Poll the arena root every ~2 minutes for `READY-summary-*.md` files; report progress briefly as models finish ("2/3 ready").
- A background task that exits without producing its READY file failed — save the tail of its output for the report and keep waiting on the rest.
- Cap each model at ~60 minutes. On timeout, mark it timed out and evaluate whatever it produced.
- Builds are slow (scaffold + install + implement, often 15–45 min). Do not declare a model stuck just because it is quiet.

## 6. Evaluate

Only after every model is ready, failed, or timed out: follow `read-only-evaluation.md` in the arena root **strictly** — read-only, no running project code, no browser automation. It defines the procedure, rubric, fairness rules, and the exact structure of the report, which is written to `$ROOT/ai-benchmark.md` with the conclusion and final score table at the top. Failed/timed-out models still get a section describing what happened and whatever partial work exists.

If subagents are available, evaluating projects in parallel (one read-only agent per project, each returning per-dimension scores with citations) is fine — the final cross-model comparison and report writing stay with the orchestrator.

## 7. Wrap up

- Show the final score table and the winner in chat, plus the arena path.
- Offer to open the report: `code-insiders "$ROOT/ai-benchmark.md"` — only run it if the user accepts.
- Leave the arena folder in place; the user may want to inspect the projects.
