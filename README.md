# dotfiles

## Install on Windows

From an elevated PowerShell on a fresh machine. winget ships with Windows 11 and installs
Chocolatey, which `install-software.ps1` uses for everything else, git included. Open a new
shell after the Chocolatey install so `choco` is on the PATH. Clone over HTTPS: the SSH keys
come back later from the dev settings backup, and commits need the GPG key from the same
backup before signing works.

```powershell
winget install --id Chocolatey.Chocolatey -e
# new shell
choco install git -y
irm https://claude.ai/install.ps1 | iex
git clone https://github.com/brunolm/dotfiles B:\dotfiles
cd B:\dotfiles
Set-ExecutionPolicy RemoteSigned
.\install.ps1
.\install-software.ps1
```

`install-software.ps1` installs the GitHub CLI first and runs `gh auth login` when there is no
token yet: almost every step dates its download through `gh`, and `gh api` needs to be signed in.

Claude Code is installed right after git on purpose: git gives it Git Bash for its Bash tool,
and from then on `claude` can drive the rest of the setup. Run `claude` once to log in, then
point it at `ai-instructions/` and the backup zips.

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
