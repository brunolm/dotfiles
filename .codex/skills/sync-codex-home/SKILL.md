---
name: sync-codex-home
description: Updates `~/.codex/` with `./common/.codex` by doing a diff and asking what to do with each diff.
---

# Sync Codex Home

## Overview

Do a diff between `~/.codex/` and `./common/.codex/` and for each diff, ask the user what to do to update `~/.codex/`.

Enumerate each diff and ask the user which ones they'd like to apply.

This is one way `./common/.codex/` -> `~/.codex/`. Never suggest the opposite direction unless explicitly asked.
