---
name: sync-claude-home
description: Updates `~/.claude/` with `./common/.claude` by doing a diff and asking what to do with each diff.
---

# Sync Claude Home

## Overview

Do a diff between `~/.claude/` and `./common/.claude/` and for each diff, ask the user what to do to update `~/.claude/`.

Enumerate each diff and ask the user which ones they'd like to apply.

This is one way `./common/.claude/` -> `~/.claude/`. Never suggest the opposite direction unless explicitly asked.
