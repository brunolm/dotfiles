# Before committing changes

- Make sure there are no secrets in any files being committed
  - .env vars
  - repository names (if they're private)
  - any other potential secrets

# Effort level in common/.claude/settings.json

- `effortLevel` keeps changing on disk because toggling effort while using Claude rewrites the global setting. That local drift does NOT mean the new value should be committed.
- Always commit `effortLevel` as `high` unless explicitly asked to change it. If it is explicitly changed, update this instruction to the new value too.

# When making changes on aliases

- Consider if the alias can and should be ported
  - If yes, keep windows alias <-> wsl alias in sync

# Time tracking local project

`C:\BrunoLM\Projects\time-tracking`
