function rm-rf {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  Remove-Item -Path $Path -Recurse -Force
}

function cdcp {
  (Get-Location).Path | clip
}

function Multi-Select {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items
  )

  $selected = [bool[]]::new($Items.Count)
  $pos = 0

  function Render {
    [Console]::SetCursorPosition(0, $startY)
    for ($i = 0; $i -lt $Items.Count; $i++) {
      $check = if ($selected[$i]) { 'x' } else { ' ' }
      $prefix = if ($i -eq $pos) { '>' } else { ' ' }
      Write-Host "$prefix [$check] $($Items[$i])                    "
    }
    Write-Host "`nUse Up/Down to move, Space to toggle, Enter to confirm" -NoNewline
  }

  $startY = [Console]::CursorTop
  Render

  while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
      'UpArrow' { if ($pos -gt 0) { $pos-- } }
      'DownArrow' { if ($pos -lt $Items.Count - 1) { $pos++ } }
      'Spacebar' { $selected[$pos] = !$selected[$pos] }
      'Enter' { break }
    }
    if ($key.Key -eq 'Enter') { break }
    Render
  }

  Write-Host "`n"
  $picks = for ($i = 0; $i -lt $Items.Count; $i++) { if ($selected[$i]) { $Items[$i] } }
  return $picks
}

function Show-Info {
  [CmdletBinding()]
  param()

  function Write-Row {
    param(
      [string]$Label,
      [string]$Value,
      [ConsoleColor]$Color = 'Cyan'
    )
    Write-Host ("{0,-9} " -f "$Label`:") -ForegroundColor $Color -NoNewline
    Write-Host $Value
  }

  function Test-AnyFile {
    param([string[]]$Patterns)
    foreach ($p in $Patterns) {
      if (Get-ChildItem -Path . -Filter $p -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
        return $true
      }
    }
    return $false
  }

  Write-Host "=== Prompt Summary ===" -ForegroundColor Yellow

  # Path
  Write-Row 'Path' (Get-Location).Path 'Yellow'

  # Git
  $insideGit = (& git rev-parse --is-inside-work-tree 2>$null) -eq 'true'
  if ($insideGit) {
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
    $working = (& git diff --name-only 2>$null | Measure-Object).Count
    $staged  = (& git diff --cached --name-only 2>$null | Measure-Object).Count
    $untracked = (& git ls-files --others --exclude-standard 2>$null | Measure-Object).Count
    $stash = (& git stash list 2>$null | Measure-Object).Count
    $ahead = 0; $behind = 0
    $upstream = & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $upstream) {
      $ahead  = [int](& git rev-list --count '@{u}..HEAD' 2>$null)
      $behind = [int](& git rev-list --count 'HEAD..@{u}' 2>$null)
    }
    $parts = @("branch=$branch")
    if ($upstream) { $parts += "upstream=$upstream" } else { $parts += 'upstream=(none)' }
    if ($ahead -gt 0)     { $parts += "ahead=$ahead" }
    if ($behind -gt 0)    { $parts += "behind=$behind" }
    if ($working -gt 0)   { $parts += "working=$working" }
    if ($staged -gt 0)    { $parts += "staged=$staged" }
    if ($untracked -gt 0) { $parts += "untracked=$untracked" }
    if ($stash -gt 0)     { $parts += "stash=$stash" }
    Write-Row 'Git' ($parts -join ', ') 'Cyan'
  } else {
    Write-Row 'Git' '(not a git repo)' 'DarkGray'
  }

  # Node - omp default trigger: package.json, *.js/.ts/.jsx/.tsx/.mjs/.cjs, .nvmrc
  if (Get-Command node -ErrorAction SilentlyContinue) {
    if (Test-AnyFile @('package.json','.nvmrc','*.js','*.cjs','*.mjs','*.ts','*.tsx','*.jsx')) {
      $v = (& node --version) -replace '^v',''
      Write-Row 'Node' $v 'Green'
    }
  }

  # Go - omp default trigger: *.go, go.mod
  if (Get-Command go -ErrorAction SilentlyContinue) {
    if (Test-AnyFile @('go.mod','*.go')) {
      $raw = (& go version) 2>$null
      if ($raw -match 'go(\d[\d\.]*)') { Write-Row 'Go' $Matches[1] 'Blue' }
    }
  }

  # Julia - omp default trigger: *.jl
  if (Get-Command julia -ErrorAction SilentlyContinue) {
    if (Test-AnyFile @('*.jl')) {
      $raw = (& julia --version) 2>$null
      if ($raw -match '(\d[\d\.]*)') { Write-Row 'Julia' $Matches[1] 'Magenta' }
    }
  }

  # Python - display_mode: files; trigger: *.py, requirements.txt, pyproject.toml, etc.
  if (Get-Command python -ErrorAction SilentlyContinue) {
    if (Test-AnyFile @('*.py','requirements.txt','pyproject.toml','Pipfile','setup.py','tox.ini')) {
      $raw = (& python --version 2>&1)
      if ($raw -match '(\d[\d\.]*)') {
        $v = $Matches[1]
        if ($env:VIRTUAL_ENV) { $v = "$v (venv: $(Split-Path $env:VIRTUAL_ENV -Leaf))" }
        Write-Row 'Python' $v 'Yellow'
      }
    }
  }

  # Ruby - display_mode: files; trigger: *.rb, Gemfile, Rakefile
  if (Get-Command ruby -ErrorAction SilentlyContinue) {
    if (Test-AnyFile @('*.rb','Gemfile','Rakefile','*.gemspec')) {
      $raw = (& ruby --version) 2>$null
      if ($raw -match 'ruby\s+(\S+)') { Write-Row 'Ruby' $Matches[1] 'Red' }
    }
  }

  # Azure Functions - display_mode: files; trigger: host.json, local.settings.json, function.json
  if (Test-AnyFile @('host.json','local.settings.json','function.json')) {
    Write-Row 'AzFunc' '(project detected)' 'DarkYellow'
  }

  # AWS - profile from env
  $awsProfile = if ($env:AWS_PROFILE) { $env:AWS_PROFILE } else { $env:AWS_DEFAULT_PROFILE }
  $awsRegion  = if ($env:AWS_REGION)  { $env:AWS_REGION }  else { $env:AWS_DEFAULT_REGION }
  if ($awsProfile -or $awsRegion) {
    $awsParts = @()
    if ($awsProfile) { $awsParts += "profile=$awsProfile" }
    if ($awsRegion)  { $awsParts += "region=$awsRegion" }
    Write-Row 'AWS' ($awsParts -join ', ') 'DarkYellow'
  } else {
    Write-Row 'AWS' '(no profile in env)' 'DarkGray'
  }

  # Execution time - last command from PSReadLine history
  $last = Get-History -Count 1 -ErrorAction SilentlyContinue
  if ($last) {
    $ms = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
    Write-Row 'LastCmd' "$ms ms - $($last.CommandLine)" 'DarkMagenta'
  }

  # YTM - try the YouTube Music Desktop local API (no auth)
  try {
    $ytm = Invoke-RestMethod -Uri 'http://localhost:9863/query' -TimeoutSec 1 -ErrorAction Stop
    if ($ytm -and $ytm.player -and $ytm.player.hasSong) {
      $state = if ($ytm.player.isPaused) { 'paused' } else { 'playing' }
      Write-Row 'YTM' "[$state] $($ytm.track.author) - $($ytm.track.title)" 'Green'
    } else {
      Write-Row 'YTM' '(stopped)' 'DarkGray'
    }
  } catch {
    Write-Row 'YTM' '(api unavailable)' 'DarkGray'
  }
}

function Single-Select {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items
  )

  $pos = 0

  function Render {
    [Console]::SetCursorPosition(0, $startY)
    for ($i = 0; $i -lt $Items.Count; $i++) {
      $prefix = if ($i -eq $pos) { '>' } else { ' ' }
      Write-Host "$prefix $($Items[$i])                    "
    }
    Write-Host "`nUse Up/Down to move, Enter to confirm" -NoNewline
  }

  $startY = [Console]::CursorTop
  Render

  while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
      'UpArrow' { if ($pos -gt 0) { $pos-- } }
      'DownArrow' { if ($pos -lt $Items.Count - 1) { $pos++ } }
      'Enter' { break }
    }
    if ($key.Key -eq 'Enter') { break }
    Render
  }

  Write-Host "`n"
  return $Items[$pos]
}

function Watch-MemoryHogs {
  param(
    [int]$MinMemoryMB = 500,
    [int]$RefreshSeconds = 2,
    [int]$WarnMemoryMB = 1024,
    [int]$CriticalWarnMemoryMB = 3072
  )

  $threshold = $MinMemoryMB * 1MB
  $warn = $WarnMemoryMB * 1MB
  $critical = $CriticalWarnMemoryMB * 1MB

  try {
    while ($true) {
      Clear-Host
      Write-Host "Processes using over $MinMemoryMB MB (warn >= $WarnMemoryMB MB, critical >= $CriticalWarnMemoryMB MB, refresh ${RefreshSeconds}s) - Ctrl+C to stop" -ForegroundColor Yellow
      Write-Host ("Updated: {0}" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
      Write-Host ''

      $rows = Get-Process |
        Where-Object { $_.WorkingSet64 -gt $threshold -and $_.ProcessName -ne 'Memory Compression' } |
        Sort-Object WorkingSet64 -Descending |
        ForEach-Object {
          [pscustomobject]@{
            PID_       = $_.Id
            Name       = $_.ProcessName
            MemoryMB   = [math]::Ceiling($_.WorkingSet64 / 1MB)
            CPU_s      = if ($_.CPU) { [math]::Round($_.CPU, 1) } else { 0 }
            _RawMemory = $_.WorkingSet64
          }
        }

      if (-not $rows) {
        Write-Host "(no processes above threshold)" -ForegroundColor DarkGray
      } else {
        $fmt = "{0,-7} {1,-30} {2,12} {3,10}"
        Write-Host ($fmt -f 'PID', 'Name', 'Memory(MB)', 'CPU(s)') -ForegroundColor Cyan
        Write-Host ($fmt -f '---', '----', '----------', '------') -ForegroundColor DarkCyan
        foreach ($r in $rows) {
          $color =
            if ($r._RawMemory -ge $critical) { 'Red' }
            elseif ($r._RawMemory -ge $warn) { 'Yellow' }
            else { 'White' }
          Write-Host ($fmt -f $r.PID_, $r.Name, $r.MemoryMB, $r.CPU_s) -ForegroundColor $color
        }
      }

      Start-Sleep -Seconds $RefreshSeconds
    }
  } finally {
    Write-Host "`nStopped watching." -ForegroundColor DarkGray
  }
}

