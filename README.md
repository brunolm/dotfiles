# dotfiles

Install on Windows

```
Set-ExecutionPolicy RemoteSigned
.\install.ps1
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
