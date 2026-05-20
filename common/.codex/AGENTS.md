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

- prefer early returns
- prefer truthy/falsy
- prefer async/await; avoid using then/catch
- prefer splitting a file into several smaller files to avoid creating god files
- avoid creating duplicate code, extract and refactor when possible
- once done coding, do once: review the changes for unused code, duplicated code, comments that should be pruned, coding preferences listed in global config and project config, and make adjustments

# Commit messages

1. Check the repo's style first - run git log and match the existing convention.
2. Summarize accurately by type - "add" = wholly new feature, "update" = enhancement, "fix" = bug fix, plus refactor/test/docs/chore as appropriate.
3. 1-2 sentences, focus on the "why" not the "what" - the diff already shows what changed.
4. Don't commit secrets, check for .env vars, private repo names, etc. before staging.
5. Stage specific files by name - avoid git add -A/git add . to prevent sweeping in sensitive files.
6. Always create a NEW commit, never --amend unless you explicitly ask.
7. Never --no-verify unless you explicitly ask - fix hook failures at the root.

Only commit when you explicitly ask - I don't commit proactively.
