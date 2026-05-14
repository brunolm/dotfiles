## Claude-Ask: ask Claude a prompt non-interactively and return the result inline.
function Claude-Ask {
  [CmdletBinding()]
  param(
    [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
    [string]$Effort,

    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Prompt
  )

  $args_ = @('-p')
  if ($PSBoundParameters.ContainsKey('Effort')) {
    $args_ += @('--effort', $Effort)
  }
  $args_ += ($Prompt -join ' ')

  & claude @args_
}

function Claude-AskSimple {
  param([string]$Prompt)
  $out = New-TemporaryFile
  $in  = New-TemporaryFile  # empty file, gives claude an immediate-EOF stdin
  try {
    Start-Process claude -ArgumentList "-- `"$Prompt`"" `
      -RedirectStandardInput  $in.FullName `
      -RedirectStandardOutput $out.FullName `
      -NoNewWindow -Wait
    Get-Content $out.FullName -Raw
  }
  finally {
    Remove-Item $out.FullName, $in.FullName -ErrorAction SilentlyContinue
  }
}

## Claude-AskWatching: run claude with stdout/stderr captured to temp logs.
## A background watcher tails the log for a sentinel string and kills the
## claude process tree as soon as it appears.
function Claude-AskWatching {
  [CmdletBinding()]
  param(
    [string]$Prompt   = "1+1. After answering, reply with ENDSESSIONNOW (no spaces).",
    [string]$Sentinel = 'ENDSESSIONNOW',
    [switch]$PassThru
  )

  $sessionId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
  $tempDir   = [System.IO.Path]::GetTempPath()
  $logPath   = Join-Path $tempDir "claude-session-$sessionId.log"
  $errPath   = Join-Path $tempDir "claude-session-$sessionId.err.log"
  $debugPath = Join-Path $tempDir "claude-session-$sessionId.debug.log"

  Write-Verbose "stdout: $logPath"
  Write-Verbose "stderr: $errPath"
  Write-Verbose "debug:  $debugPath"

  "[$(Get-Date -Format o)] script PID=$PID logPath=$logPath" |
    Set-Content -Path $debugPath -Encoding UTF8

  # Spawn claude with stdout/stderr redirected to files. claude detects the
  # non-TTY stdout and runs in non-interactive plain-output mode.
  # `--` ends option parsing so any leading dashes in the prompt are positional.
  # Quote the prompt manually so Start-Process passes it as a single arg.
  $quotedPrompt = '"' + ($Prompt -replace '"', '\"') + '"'
  $claudeProc = Start-Process -FilePath claude -ArgumentList "-- $quotedPrompt" `
    -RedirectStandardOutput $logPath -RedirectStandardError $errPath `
    -NoNewWindow -PassThru

  "[$(Get-Date -Format o)] claude started, claudePID=$($claudeProc.Id)" |
    Add-Content -Path $debugPath -Encoding UTF8

  $watcher = Start-Job -ScriptBlock {
    param($logPath, $debugPath, $targetPid, $sentinel)

    function Write-Dbg($msg) {
      Add-Content -Path $debugPath -Value "[$(Get-Date -Format o)] $msg" -Encoding UTF8
    }

    function Stop-ProcessAndChildren {
      param([int]$ProcId)
      $kids = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcId" -ErrorAction SilentlyContinue
      foreach ($k in $kids) { Stop-ProcessAndChildren -ProcId $k.ProcessId }
      Stop-Process -Id $ProcId -Force -ErrorAction SilentlyContinue
    }

    try {
      Write-Dbg "watcher started, jobPID=$PID, targetPID=$targetPid, sentinel=$sentinel"
      $ticks = 0
      while ($true) {
        Start-Sleep -Milliseconds 500
        $ticks++

        if (-not (Get-Process -Id $targetPid -ErrorAction SilentlyContinue)) {
          Write-Dbg "tick=$ticks target $targetPid exited on its own; watcher done"
          break
        }

        if (-not (Test-Path $logPath)) {
          if ($ticks % 10 -eq 0) { Write-Dbg "tick=$ticks log not present yet" }
          continue
        }

        $content = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
        $size    = (Get-Item $logPath).Length
        if ($ticks % 10 -eq 0) {
          Write-Dbg "tick=$ticks logSize=$size match=$([bool]($content -match [regex]::Escape($sentinel)))"
        }

        if ($content -and $content -match [regex]::Escape($sentinel)) {
          Write-Dbg "MATCH at tick=$ticks, logSize=$size"
          $ctx = ($content -split "`n" | Select-String -Pattern ([regex]::Escape($sentinel)) -Context 2,2 | Out-String)
          Add-Content -Path $debugPath -Encoding UTF8 -Value "`n--- Match context ---`n$ctx"

          Stop-ProcessAndChildren -ProcId $targetPid
          Write-Dbg "claude killed, watcher exiting"
          break
        }
      }
    }
    catch {
      Write-Dbg "ERROR in watcher: $($_ | Out-String)"
      throw
    }
  } -ArgumentList $logPath, $debugPath, $claudeProc.Id, $Sentinel

  try {
    $claudeProc.WaitForExit()
  }
  finally {
    $jobOut = Receive-Job $watcher -ErrorAction SilentlyContinue 2>&1 | Out-String
    if ($jobOut.Trim()) {
      Add-Content -Path $debugPath -Encoding UTF8 -Value "`n--- Job output / errors ---`n$jobOut"
    }
    Stop-Job   $watcher -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $watcher -ErrorAction SilentlyContinue | Out-Null
  }

  if (Test-Path $logPath) {
    Get-Content -Path $logPath -Raw | Write-Host
  }

  if ($DebugPreference -eq 'SilentlyContinue') {
    Remove-Item -Path $logPath, $errPath, $debugPath -ErrorAction SilentlyContinue
  }

  if ($PassThru) {
    [pscustomobject]@{
      SessionId = $sessionId
      LogPath   = $logPath
      ErrPath   = $errPath
      DebugPath = $debugPath
      ExitCode  = $claudeProc.ExitCode
    }
  }
}
