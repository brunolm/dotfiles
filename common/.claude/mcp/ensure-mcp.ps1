<#
.SYNOPSIS
  headersHelper for the local HTTP MCP servers: starts the server if nothing listens on its port.

.DESCRIPTION
  Claude Code runs this before every connect and reconnect to a server registered with it, with
  CLAUDE_CODE_MCP_SERVER_NAME set, and gives up after 10 seconds. The server named there is looked
  up in ~/.claude/mcp-servers.json (written by install-mcp.ps1). If its port is closed, the server
  is started detached, so one process is shared by every session and outlives the one that
  started it. Output is always an empty header object: failures go to stderr and the server log,
  and Claude Code's own connect retries run this again.
#>
$ErrorActionPreference = "Stop"

$SpecPath = Join-Path $HOME ".claude\mcp-servers.json"
$LogDir = Join-Path $HOME ".claude\mcp-logs"

# Leaves headroom under Claude Code's 10-second limit for pwsh startup and the JSON output.
$StartupBudget = [TimeSpan]::FromSeconds(8)

function Invoke-EnsureMcp {
  try {
    $name = $env:CLAUDE_CODE_MCP_SERVER_NAME
    if (!$name) {
      throw "CLAUDE_CODE_MCP_SERVER_NAME is not set; this script is meant to run as a headersHelper."
    }
    Start-McpServer $name
  } catch {
    [Console]::Error.WriteLine("ensure-mcp: $($_.Exception.Message)")
  }

  "{}"
}

function Test-Port($Port) {
  $client = [Net.Sockets.TcpClient]::new()
  try {
    return $client.ConnectAsync("127.0.0.1", $Port).Wait(300)
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

function Start-McpServer($Name) {
  $spec = Get-LaunchSpec $Name
  if (Test-Port $spec.port) {
    return
  }

  # Several sessions often connect to the same server at once; only one of them launches it.
  $mutex = [Threading.Mutex]::new($false, "Local\claude-mcp-$Name")
  $deadline = [DateTime]::UtcNow + $StartupBudget
  $owned = $false
  try {
    try {
      $owned = $mutex.WaitOne($StartupBudget)
    } catch [Threading.AbandonedMutexException] {
      $owned = $true
    }

    if (!$owned -or (Test-Port $spec.port)) {
      return
    }

    Start-Detached $Name $spec
    Wait-Port $spec.port $deadline
  } finally {
    if ($owned) {
      $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
  }
}

function Get-LaunchSpec($Name) {
  if (!(Test-Path $SpecPath)) {
    throw "$SpecPath does not exist. Run install-mcp.ps1 from the dotfiles repo."
  }

  $spec = (Get-Content $SpecPath -Raw | ConvertFrom-Json -AsHashtable)[$Name]
  if (!$spec) {
    throw "No launch spec for '$Name' in $SpecPath. Run install-mcp.ps1 -Only $Name."
  }
  return $spec
}

function Start-Detached($Name, $Spec) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
  $log = Join-Path $LogDir "$Name.log"

  $command = Resolve-Command $Spec.command
  $line = (@($command) + @($Spec.args) | ForEach-Object { Format-Argument $_ }) -join " "
  # /s makes cmd strip only the outermost quotes, so every argument keeps its own quoting.
  $commandLine = "cmd.exe /d /s /c `"$line > `"$log`" 2>&1`""

  # A WMI-created process belongs to neither Claude Code's process tree nor its job object, so
  # closing the session that started the server does not take the server down with it.
  $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
  $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine               = $commandLine
    CurrentDirectory          = $Spec.cwd
    ProcessStartupInformation = $startup
  }
  if ($result.ReturnValue -ne 0) {
    throw "Win32_Process.Create failed with code $($result.ReturnValue) for: $commandLine"
  }
}

function Resolve-Command($Command) {
  if (Test-Path $Command) {
    return $Command
  }

  # A runtime upgrade can remove the path recorded at install time; use whatever PATH has now.
  $name = [IO.Path]::GetFileNameWithoutExtension($Command)
  $found = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (!$found) {
    throw "Cannot find $Command, and '$name' is not on PATH. Re-run install-mcp.ps1."
  }
  return $found.Source
}

function Wait-Port($Port, $Deadline) {
  while ([DateTime]::UtcNow -lt $Deadline) {
    if (Test-Port $Port) {
      return
    }
    Start-Sleep -Milliseconds 200
  }
  throw "Server did not open port $Port in time; see $LogDir."
}

function Format-Argument($Value) {
  if ($Value -notmatch '[\s"]') {
    return $Value
  }
  return '"' + ($Value -replace '"', '\"') + '"'
}

Invoke-EnsureMcp
