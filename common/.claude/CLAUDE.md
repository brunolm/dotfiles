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
