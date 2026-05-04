# General Instructions

## Environment

- **OS:** Windows 11 Pro
- **Terminal:** PowerShell

## Rules

- Always tailor terminal commands and scripts to the current environment (Windows 11 Pro + PowerShell). Do not suggest Unix/macOS-specific commands or syntax unless explicitly requested.
- **Tool selection for shell commands:** Use the **PowerShell tool** for all shell commands by default. Only use the **Bash tool** when running a genuine POSIX script (e.g. a `.sh` file, WSL command, or git-bash-only utility). Never put PowerShell syntax (`$env:`, `Get-*`/`Set-*` cmdlets, backtick line continuations, `@'...'@` here-strings, `&&`/`||` between cmdlets, etc.) into a Bash tool call — route it through the PowerShell tool instead. If unsure which shell a command targets, default to PowerShell.
- Always show a summary and ask permission before:
  - sending emails
  - making changes on the calendar
  - making changes on Linear
