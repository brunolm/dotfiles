# dotfiles

## Install on Windows

From an elevated PowerShell on a fresh machine. winget ships with Windows 11, so git needs no
manual download. Clone over HTTPS: the SSH keys come back later from the dev settings backup,
and commits need the GPG key from the same backup before signing works.

```powershell
winget install --id Git.Git -e
irm https://claude.ai/install.ps1 | iex
git clone https://github.com/brunolm/dotfiles C:\BrunoLM\Projects\dotfiles
cd C:\BrunoLM\Projects\dotfiles
Set-ExecutionPolicy RemoteSigned
.\install.ps1
```

Claude Code is installed second on purpose: git gives it Git Bash for its Bash tool, and from
then on `claude` can drive the rest of the setup. Run `claude` once to log in, then point it at
`ai-instructions/` and the backup zips.

`install.ps1` creates symlinks, so it needs the elevated shell (or Developer Mode). Once the
backups are restored, switch the remote back to SSH:

```powershell
git remote set-url origin git@github.com:brunolm/dotfiles.git
```

## MCP servers

Clones [brunolm/ai](https://github.com/brunolm/ai) into `C:\BrunoLM\Projects\ai` if it is not there
yet, builds each MCP server it contains, and registers them all with Claude Code at user scope.
Idempotent — re-run it any time to rebuild and refresh the registrations.

```
.\install-mcp.ps1
```

Servers needing credentials get a `.env` seeded from their example, which you then fill in. Useful
switches: `-Only <name>`, `-SkipBuild`, `-SkipRegister`, `-Root <path>`.

## Info

Custom Startup folder

```
C:\System\Startup
```

## Manually check ps modules and run reg files
