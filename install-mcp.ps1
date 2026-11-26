<#
.SYNOPSIS
  Clones, builds and registers the MCP servers from the brunolm/ai repo with Claude Code.

.DESCRIPTION
  Idempotent — safe to run as many times as you like. Missing repos are cloned, present ones are
  left alone; dependencies are installed with the package manager's own idempotent commands; and
  each server is re-registered at user scope so a changed path is picked up rather than duplicated.

  Servers are registered as HTTP servers on fixed localhost ports, so every Claude Code session
  shares one process per server. Nothing starts them up front: each registration's headersHelper
  (common\.claude\mcp\ensure-mcp.ps1) starts its server on the first connect that finds it down.
  A running server is stopped before its rebuild, and the next connect starts the new build.

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
  [string]$Root = "B:\ai",
  [string[]]$Only,
  [switch]$SkipBuild,
  [switch]$SkipRegister
)

$ErrorActionPreference = "Stop"

# Native exit codes are checked explicitly, so a non-zero result must not throw on its own.
$PSNativeCommandUseErrorActionPreference = $false

$RepoUrl = "git@github.com:brunolm/ai.git"

# Claude Code runs this before connecting to each server; install.ps1 links it in from common\.claude.
$HeadersHelperScript = Join-Path $HOME ".claude\mcp\ensure-mcp.ps1"

# Machine-local launch commands read by ensure-mcp.ps1; kept out of the repo since they hold
# absolute paths.
$LaunchSpecPath = Join-Path $HOME ".claude\mcp-servers.json"

# One entry per server. Name is what it registers as in Claude Code — keep it stable, or a rename
# leaves the old registration orphaned. Each server runs over HTTP on its own fixed localhost Port,
# shared by every session; Command and Args (which receive the server's folder and that port) are
# how ensure-mcp.ps1 starts it when nothing is listening yet.
$Servers = @(
  @{
    Name     = "mal-mcp"
    Folder   = "mal-mcp"
    Requires = @("bun")
    SeedEnv  = $true
    Build    = { param($Dir) Invoke-Step $Dir "bun" @("install") }
    Port     = 47801
    Command  = { "bun" }
    Args     = { param($Dir, $Port) @("$Dir/src/index.ts", "--port", $Port) }
  },
  @{
    Name     = "toggl"
    Folder   = "toggl-mcp"
    Requires = @("bun")
    SeedEnv  = $true
    Build    = { param($Dir) Invoke-Step $Dir "bun" @("install") }
    Port     = 47802
    Command  = { "bun" }
    Args     = { param($Dir, $Port) @("run", "$Dir/src/index.ts", "--port", $Port) }
  },
  @{
    Name     = "patchright"
    Folder   = "patchright-mcp"
    Requires = @("node", "npm")
    Build    = { param($Dir) Invoke-Step $Dir "npm" @("install") }
    Port     = 47803
    Command  = { "node" }
    Args     = {
      param($Dir, $Port)
      $profileDir = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data MCP"
      @(
        "$Dir/cli.js", "--cdp-endpoint=http://localhost:9222", "--auto-launch-chrome=$($profileDir -replace '\\', '/')",
        # Without an explicit host it binds "localhost", which can resolve to ::1 only.
        "--port", $Port, "--host", "127.0.0.1"
      )
    }
  },
  @{
    Name     = "stealth-fetch"
    Folder   = "stealth-fetch-mcp"
    Requires = @("mise")
    # server.py declares its dependencies inline (PEP 723); mise only has to supply python and uv.
    Build    = { param($Dir) Invoke-Step $Dir "mise" @("install") }
    Port     = 47804
    Command  = { "mise" }
    Args     = { param($Dir, $Port) @("x", "-C", $Dir, "--", "uv", "run", "--script", "$Dir/server.py", "--port", $Port) }
  },
  @{
    Name     = "input"
    Folder   = "input-mcp"
    Requires = @("dotnet")
    Build    = {
      param($Dir)
      Invoke-Step $Dir "dotnet" @("publish", "src/InputMcp", "-c", "Release", "-o", "publish", "--nologo")
    }
    Port     = 47805
    Command  = { param($Dir) "$Dir/publish/input-mcp.exe" }
    Args     = { param($Dir, $Port) @("--port", $Port) }
  },
  @{
    Name     = "screenshot"
    Folder   = "screenshot-mcp"
    Requires = @("dotnet")
    Build    = {
      param($Dir)
      Invoke-Step $Dir "dotnet" @("publish", "src/ScreenshotMcp", "-c", "Release", "-o", "publish", "--nologo")
    }
    Port     = 47806
    Command  = { param($Dir) "$Dir/publish/screenshot-mcp.exe" }
    Args     = { param($Dir, $Port) @("--port", $Port) }
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

  Stop-RunningServer $Server

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

# A running server keeps its old code and arguments and locks its .exe against a rebuild. Stopping
# it is safe: the next connect from any session starts it again through ensure-mcp.ps1.
function Stop-RunningServer($Server) {
  $listener = Get-NetTCPConnection -LocalPort $Server.Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (!$listener) {
    return
  }

  Stop-Process -Id $listener.OwningProcess -Force
  Write-Host "  Stopped the running server (pid $($listener.OwningProcess))."
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

  if (!(Test-Path $HeadersHelperScript)) {
    Write-Warning "  Skipping registration — $HeadersHelperScript is missing; run install.ps1 first."
    return "failed"
  }

  $normalized = $Dir -replace "\\", "/"
  $command = & $Server.Command $normalized
  $arguments = @(& $Server.Args $normalized $Server.Port | ForEach-Object { "$_" })

  if (!(Test-Path $command) -and !(Test-Tool $command)) {
    Write-Warning "  Skipping registration — $command does not exist."
    return "failed"
  }

  # ensure-mcp.ps1 runs outside this shell's PATH (mise only activates in interactive shells), so
  # it gets the absolute path.
  $commandPath = if (Test-Path $command) { $command } else { (Get-Command $command).Source }
  Save-LaunchSpec $Server.Name @{
    port    = $Server.Port
    cwd     = $normalized
    command = $commandPath -replace "\\", "/"
    args    = $arguments
  }

  $url = "http://127.0.0.1:$($Server.Port)/mcp"
  $entry = @{
    type          = "http"
    url           = $url
    headersHelper = "pwsh -NoProfile -NonInteractive -File `"$($HeadersHelperScript -replace '\\', '/')`""
  } | ConvertTo-Json -Compress

  # Remove first so a changed path replaces the old entry rather than colliding with it.
  & claude mcp remove $Server.Name --scope user 2>&1 | Out-Null

  & claude mcp add-json $Server.Name $entry --scope user | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "  Registration failed (exit $LASTEXITCODE)."
    return "failed"
  }

  Write-Host "  Registered: $url, started on demand as $command $($arguments -join ' ')"
  return "ok"
}

function Save-LaunchSpec($Name, $Spec) {
  $specs = if (Test-Path $LaunchSpecPath) { Get-Content $LaunchSpecPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
  $specs[$Name] = $Spec
  $specs | ConvertTo-Json -Depth 5 | Set-Content $LaunchSpecPath
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
