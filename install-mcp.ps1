<#
.SYNOPSIS
  Clones, builds and registers the MCP servers from the brunolm/ai repo with Claude Code.

.DESCRIPTION
  Idempotent — safe to run as many times as you like. Missing repos are cloned, present ones are
  left alone; dependencies are installed with the package manager's own idempotent commands; and
  each server is re-registered at user scope so a changed path is picked up rather than duplicated.

  A server whose toolchain is missing is skipped with a warning instead of failing the whole run.

.PARAMETER Root
  Where the ai repo lives, or should be cloned to.

.PARAMETER Only
  Install just these servers, by registered name.

.PARAMETER SkipBuild
  Register the servers without installing or compiling anything.

.PARAMETER SkipRegister
  Build the servers without touching the Claude Code config.

.EXAMPLE
  .\install-mcp.ps1
  .\install-mcp.ps1 -Only screenshot -SkipRegister
#>
[CmdletBinding()]
param(
  [string]$Root = "C:\BrunoLM\Projects\ai",
  [string[]]$Only,
  [switch]$SkipBuild,
  [switch]$SkipRegister
)

$ErrorActionPreference = "Stop"

# Native exit codes are checked explicitly, so a non-zero result must not throw on its own.
$PSNativeCommandUseErrorActionPreference = $false

$RepoUrl = "git@github.com:brunolm/ai.git"

# One entry per server. Name is what it registers as in Claude Code — keep it stable, or a rename
# leaves the old registration orphaned. Command and Args receive the server's folder.
$Servers = @(
  @{
    Name     = "mal-mcp"
    Folder   = "mal-mcp"
    Requires = @("bun")
    SeedEnv  = $true
    Build    = { param($Dir) Invoke-Step $Dir "bun" @("install") }
    Command  = { "bun" }
    Args     = { param($Dir) @("$Dir/src/index.ts") }
  },
  @{
    Name     = "toggl"
    Folder   = "toggl-mcp"
    Requires = @("bun")
    SeedEnv  = $true
    Build    = { param($Dir) Invoke-Step $Dir "bun" @("install") }
    Command  = { "bun" }
    Args     = { param($Dir) @("run", "$Dir/src/index.ts") }
  },
  @{
    Name     = "patchright"
    Folder   = "patchright-mcp"
    Requires = @("node", "npm")
    Build    = { param($Dir) Invoke-Step $Dir "npm" @("install") }
    Command  = { "node" }
    Args     = {
      param($Dir)
      $profileDir = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data MCP"
      @("$Dir/cli.js", "--cdp-endpoint=http://localhost:9222", "--auto-launch-chrome=$($profileDir -replace '\\', '/')")
    }
  },
  @{
    Name     = "stealth-fetch"
    Folder   = "stealth-fetch-mcp"
    Requires = @("mise")
    # server.py declares its dependencies inline (PEP 723); mise only has to supply python and uv.
    Build    = { param($Dir) Invoke-Step $Dir "mise" @("install") }
    Command  = { "mise" }
    Args     = { param($Dir) @("x", "-C", $Dir, "--", "uv", "run", "--script", "$Dir/server.py") }
  },
  @{
    Name     = "input"
    Folder   = "input-mcp"
    Requires = @("dotnet")
    Build    = {
      param($Dir)
      Invoke-Step $Dir "dotnet" @("publish", "src/InputMcp", "-c", "Release", "-o", "publish", "--nologo")
    }
    Command  = { param($Dir) "$Dir/publish/input-mcp.exe" }
    Args     = { @() }
  },
  @{
    Name     = "screenshot"
    Folder   = "screenshot-mcp"
    Requires = @("dotnet")
    Build    = {
      param($Dir)
      Invoke-Step $Dir "dotnet" @("publish", "src/ScreenshotMcp", "-c", "Release", "-o", "publish", "--nologo")
    }
    Command  = { param($Dir) "$Dir/publish/screenshot-mcp.exe" }
    Args     = { @() }
  }
)

function Install-McpServers {
  $selected = if ($Only) { $Servers | Where-Object { $_.Name -in $Only } } else { $Servers }

  if (!$selected) {
    throw "No server matches -Only $($Only -join ', '). Known servers: $(($Servers.Name) -join ', ')."
  }

  Sync-Repo

  $results = foreach ($server in $selected) { Install-Server $server }

  Write-Host ""
  $results | Format-Table Name, Build, Registered, Notes -AutoSize

  $needsEnv = @($results | Where-Object { $_.EnvPath })
  if ($needsEnv) {
    Write-Host " ======= NEXT ======= " -ForegroundColor Yellow
    foreach ($result in $needsEnv) {
      Write-Host " - Fill in credentials: $($result.EnvPath)"
    }
    Write-Host " ======= /NEXT ======= " -ForegroundColor Yellow
  }

  Write-Host ""
  if ($results | Where-Object { $_.Build -eq "failed" -or $_.Registered -eq "failed" }) {
    Write-Host -ForegroundColor Red "Finished with errors — see above."
    return
  }

  Write-Host -ForegroundColor Green "MCP servers installed!"
}

function Sync-Repo {
  if (!(Test-Tool "git")) {
    throw "git is not on PATH."
  }

  if (!(Test-Path (Join-Path $Root ".git"))) {
    Write-Host "Cloning $RepoUrl into $Root..." -ForegroundColor Cyan
    $parent = Split-Path -Parent $Root
    if ($parent -and !(Test-Path $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Invoke-Step $parent "git" @("clone", "--recurse-submodules", $RepoUrl, $Root)
    return
  }

  Write-Host "Updating submodules in $Root..." -ForegroundColor Cyan
  Invoke-Step $Root "git" @("submodule", "update", "--init", "--recursive")
}

function Install-Server($Server) {
  $dir = Join-Path $Root "mcp\$($Server.Folder)"
  $result = [pscustomobject]@{
    Name       = $Server.Name
    Build      = "skipped"
    Registered = "skipped"
    Notes      = ""
    EnvPath    = ""
  }

  Write-Host ""
  Write-Host "=== $($Server.Name) ===" -ForegroundColor Cyan

  if (!(Test-Path $dir)) {
    $result.Notes = "missing folder $dir"
    Write-Warning "  $($result.Notes)"
    return $result
  }

  $missing = @($Server.Requires | Where-Object { !(Test-Tool $_) })
  if ($missing) {
    $result.Notes = "needs $($missing -join ', ')"
    Write-Warning "  Skipping — $($result.Notes) on PATH."
    return $result
  }

  if ($Server.SeedEnv -and (Copy-EnvExample $dir)) {
    $result.Notes = "created .env, add credentials"
    $result.EnvPath = Join-Path $dir ".env"
  }

  if (!$SkipBuild) {
    $result.Build = Invoke-Build $Server $dir
    if ($result.Build -eq "failed") {
      return $result
    }
  }

  if (!$SkipRegister) {
    $result.Registered = Register-Server $Server $dir
  }

  return $result
}

function Copy-EnvExample($Dir) {
  $env_ = Join-Path $Dir ".env"
  $example = Join-Path $Dir ".env.example"

  if ((Test-Path $env_) -or !(Test-Path $example)) {
    return $false
  }

  Copy-Item -Path $example -Destination $env_
  Write-Warning "  Created $env_ from the example — it still needs real credentials."
  return $true
}

function Invoke-Build($Server, $Dir) {
  Write-Host "  Building..."

  try {
    & $Server.Build $Dir
    return "ok"
  } catch {
    Write-Warning "  Build failed: $($_.Exception.Message)"
    return "failed"
  }
}

function Register-Server($Server, $Dir) {
  if (!(Test-Tool "claude")) {
    Write-Warning "  Skipping registration — claude is not on PATH."
    return "skipped"
  }

  $normalized = $Dir -replace "\\", "/"
  $command = & $Server.Command $normalized
  $arguments = @(& $Server.Args $normalized)

  if (!(Test-Path $command) -and !(Test-Tool $command)) {
    Write-Warning "  Skipping registration — $command does not exist."
    return "failed"
  }

  # Remove first so a changed path replaces the old entry rather than colliding with it.
  & claude mcp remove $Server.Name --scope user 2>&1 | Out-Null

  & claude mcp add $Server.Name --scope user -- $command @arguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "  Registration failed (exit $LASTEXITCODE)."
    return "failed"
  }

  Write-Host "  Registered: $command $($arguments -join ' ')"
  return "ok"
}

function Invoke-Step($Dir, $Command, $Arguments) {
  Push-Location $Dir
  try {
    & $Command @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "$Command $($Arguments -join ' ') exited with $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Test-Tool($Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Install-McpServers
