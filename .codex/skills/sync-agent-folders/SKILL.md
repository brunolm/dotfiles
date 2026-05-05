---
name: sync-agent-folders
description: Keep `common/.claude/` and `common/.codex/` in lockstep. Use when the user edits an instruction, skill, permission, or config in one folder and wants the equivalent change mirrored to the other - or when they ask to "sync the agent folders", "check for drift between Claude and Codex", or similar.
---

# Sync Agent Folders

## Overview

The dotfiles repo keeps parallel configuration for two coding agents under [common/](../../../common/). Anything added to one side should land in the other in its equivalent form. This skill is the procedure for performing that sync (in either direction) and for auditing drift.

## File mapping

| Claude side                                                                | Codex side                                                               | Format-equivalent?                              |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------- |
| [common/.claude/CLAUDE.md](../../../common/.claude/CLAUDE.md)              | [common/.codex/AGENTS.md](../../../common/.codex/AGENTS.md)              | Yes - same markdown, with text transforms below |
| [common/.claude/settings.json](../../../common/.claude/settings.json)      | [common/.codex/config.toml](../../../common/.codex/config.toml)          | No - semantic mapping (see below)               |
| [common/.claude/skills/`<name>`/SKILL.md](../../../common/.claude/skills/) | [common/.codex/skills/`<name>`/SKILL.md](../../../common/.codex/skills/) | Yes - same markdown, with text transforms below |
| `common/.claude/skills/<name>/references/*`                                | `common/.codex/skills/<name>/references/*`                               | Yes                                             |
| `common/.claude/skills/<name>/scripts/*`                                   | `common/.codex/skills/<name>/scripts/*`                                  | Yes                                             |
| (none)                                                                     | `common/.codex/skills/<name>/agents/openai.yaml`                         | Codex-only - leave intact                       |

A skill must exist in BOTH `skills/` trees. If the user adds one to a single side, mirror it.

## Workflow

### 1. Identify what changed

- If the user says "I just edited X, sync it" - diff X against its mirror.
- If the user says "check for drift" or runs the skill with no specifics - walk every pair in the mapping table and report differences.

Use `git status` and `git diff` against `common/.claude/` and `common/.codex/` to see uncommitted edits.

### 2. Decide the source of truth

- If only one side was edited -> that side wins.
- If both sides were edited and conflict -> STOP and ask the user which is canonical. Do not guess.
- If the user named a side ("apply this to both", "I changed CLAUDE.md, copy over") -> that side wins.

### 3. Apply the equivalent change to the other side

Use the rules in the next sections (text transforms, settings <-> TOML mapping). Verify by re-diffing after the edit.

### 4. Report

Summarize what was synced and flag anything you intentionally did NOT sync (e.g., Codex-only `agents/openai.yaml`, Claude-only permission entries that have no Codex equivalent).

## Text transforms (markdown <-> markdown)

When mirroring `CLAUDE.md` <-> `AGENTS.md` or `SKILL.md` <-> `SKILL.md`, the _content_ is the same but the Codex side uses ASCII-only punctuation. Apply these substitutions when copying **Claude -> Codex**:

| Claude (source)                                             | Codex (target) |
| ----------------------------------------------------------- | -------------- |
| `—` (em dash, U+2014)                                       | `-`            |
| `–` (en dash, U+2013)                                       | `-`            |
| `…` (ellipsis, U+2026)                                      | `...`          |
| `²` (superscript 2, U+00B2)                                 | `^2`           |
| `³` (superscript 3, U+00B3)                                 | `^3`           |
| `'` `'` (curly singles, U+2018/U+2019)                      | `'`            |
| `"` `"` (curly doubles, U+201C/U+201D)                      | `"`            |
| `→` (right arrow, U+2192)                                   | `->`           |
| `↔` (left-right arrow, U+2194)                              | `<->`          |
| `CLAUDE.md`                                                 | `AGENTS.md`    |
| `Claude` (when referring to the agent name in instructions) | `Codex`        |

When copying **Codex -> Claude**, reverse only the `AGENTS.md` -> `CLAUDE.md` and `Codex` -> `Claude` substitutions. Do NOT promote ASCII punctuation back to unicode - leave dashes/quotes as the user wrote them; the Claude side is allowed to contain either.

The `brunolm-code-review` skill at [common/.codex/skills/brunolm-code-review/SKILL.md](../../../common/.codex/skills/brunolm-code-review/SKILL.md) is a good worked example of these transforms.

## settings.json <-> config.toml (semantic mapping)

These files are NOT line-for-line equivalents. Map by intent:

| Claude `settings.json`                     | Codex `config.toml`                                                                                                                                                                               |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"effortLevel": "xhigh"`                   | `model_reasoning_effort = "xhigh"`                                                                                                                                                                |
| `"permissions"` (allow / ask / deny lists) | No direct equivalent - Codex uses `approval_policy` + `sandbox_mode`. **Do not try to translate individual allow entries.** Add a comment in `config.toml` if a meaningful policy shift is needed. |
| `"autoUpdatesChannel"`                     | (no equivalent - skip)                                                                                                                                                                            |
| `"skipAutoPermissionPrompt"`               | (covered by `approval_policy = "on-request"` and `sandbox_mode`)                                                                                                                                  |

When the user changes a permission entry on the Claude side, the default action is **do nothing on the Codex side** and tell the user that permissions don't translate. Only touch `config.toml` if the change crosses into territory Codex actually models (effort, model name, sandbox, trusted projects).

The current `config.toml` has a header comment explaining this - preserve it.

## Skill creation: when adding a new skill

If the user is adding a brand-new skill, create it in BOTH locations:

1. `common/.claude/skills/<name>/SKILL.md` - Claude flavor (CLAUDE.md references, unicode dashes OK).
2. `common/.codex/skills/<name>/SKILL.md` - Codex flavor (AGENTS.md references, ASCII only).
3. `common/.codex/skills/<name>/agents/openai.yaml` - Codex requires this. Use the existing one in this skill's folder as a template (interface block with `display_name`, `short_description`, `default_prompt`).
4. Mirror any `references/` or `scripts/` directories on both sides.

## Don't sync

- `common/.codex/skills/<name>/agents/` - Codex-only, no Claude equivalent.
- Generated/output files (`.branch-docs/`, etc.) if they ever appear.
- `common/.codex/config.toml` `[projects.*]` trust entries - those are environment-specific, not instruction content.

## Verification

After syncing, run a final pass:

```powershell
# Quick drift check on the markdown pair
git diff --no-index common/.claude/CLAUDE.md common/.codex/AGENTS.md

# Per-skill diff (substitute the skill name)
git diff --no-index common/.claude/skills/<name>/SKILL.md common/.codex/skills/<name>/SKILL.md
```

The expected diff between equivalent files is ONLY the text transforms listed above. Anything else is real drift and should be resolved.
