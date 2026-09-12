# The execution policy is persisted in the registry (HKLM/HKCU ShellIds, shared by pwsh 7 and
# Windows PowerShell 5.1), so it survives reboots and does not belong in a profile. On a new
# machine, run this once from an elevated shell:
#   Set-ExecutionPolicy RemoteSigned

# Grok privacy: second layer over common/.grok/config.toml — remote settings can
# override the TOML, but env vars win the precedence resolution.
$env:GROK_TELEMETRY_ENABLED = "0"
$env:GROK_TELEMETRY_TRACE_UPLOAD = "0"
$env:GROK_TELEMETRY_MIXPANEL_ENABLED = "0"
$env:GROK_FEEDBACK_ENABLED = "0"

function Test-InteractiveShell {
  if ($host.Name -ne 'ConsoleHost') {
    return $false
  }

  if (-not [Environment]::UserInteractive) {
    return $false
  }

  try {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
      return $false
    }
  }
  catch {
    return $false
  }

  return $true
}

$IsInteractiveShell = Test-InteractiveShell

# ~/profile.ps1 is a symlink into the repo; resolve it so the repo can live anywhere.
$profileItem = Get-Item -LiteralPath $PSCommandPath -Force
$DotfilesWindowsDir = if ($profileItem.Target) { Split-Path (@($profileItem.Target)[0]) } else { $PSScriptRoot }

# oh-my-posh init only prints a one-line loader for an init script it keeps in its own cache, so
# remembering that script's path skips launching the binary on every shell. The file name carries a
# config and version hash, so a missing file means oh-my-posh has to print a fresh loader.
function Initialize-OhMyPosh($config) {
  $pointer = Join-Path $env:LOCALAPPDATA 'dotfiles\oh-my-posh-init.txt'
  $init = if (Test-Path -LiteralPath $pointer) { (Get-Content -LiteralPath $pointer -Raw).Trim() }

  if (!$init -or !(Test-Path -LiteralPath $init)) {
    $loader = (oh-my-posh init pwsh --config $config) -join "`n"
    $init = [regex]::Match($loader, "& '([^']+)'").Groups[1].Value
    if (!$init) {
      $loader | Invoke-Expression
      return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $pointer) | Out-Null
    Set-Content -LiteralPath $pointer -Value $init
  }

  # The loader sets both; the session id keys oh-my-posh's per-shell state, so every shell needs
  # its own.
  $env:POSH_SESSION_ID = [guid]::NewGuid().ToString()
  $env:POSH_CONFIG = $config
  & $init
}

if ($IsInteractiveShell) {
  try {
    # $host.UI.RawUI.ForegroundColor = "White";
    # $host.UI.RawUI.BackgroundColor = "Black";
    # Set-Location D:\
    # Clear-Host
    Initialize-OhMyPosh (Join-Path $DotfilesWindowsDir '_brunolm.omp.json')
  }
  catch {}
}

## PSReadLine
if ($IsInteractiveShell) {
  try {
    Import-Module PSReadLine
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
  }
  catch {}
}
##

function zsh() {
  C:\Windows\system32\bash.exe -c /usr/bin/zsh $args
}

function edit-profile {
  Write-Output "${env:HomeDrive}${env:HomePath}\profile.ps1"
  Write-Output $Profile
  code "${env:HomeDrive}${env:HomePath}\profile.ps1"
  code $Profile
}

function edit-aliases() {
  code $env:Home/aliases
}

function edit-hosts {
  Write-Output "C:\Windows\System32\drivers\etc\hosts"
  Start-Process -verb runas code "C:\Windows\System32\drivers\etc\hosts"
}

function edit-history {
  code (Get-PSReadlineOption).HistorySavePath
}

##
## Modules
#

## Audio
# Install-Module -Name AudioDeviceCmdlets

## Update modules
# powershell -noprofile -command "Install-Module PSReadline -Force -SkipPublisherCheck"
# Update-Module posh-git
# Install-Module -Name Pscx

##
## Load modules
##
# Import-Module PSReadline
# Import-Module PowerTab

# $global:GitPromptSettings.WorkingForegroundColor = "Red"

# Together these cost around a second to import and neither is needed to draw the first prompt, so
# they load on the first idle moment instead of holding up the shell. install.ps1 installs both; a
# machine that has not been through it yet gets a plain prompt instead of an import error.
if ($IsInteractiveShell) {
  Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    foreach ($module in 'posh-git', 'Terminal-Icons') {
      Import-Module $module -Global -ErrorAction SilentlyContinue
    }
  } | Out-Null
}
##

if (Test-Path "${env:HomeDrive}${env:HomePath}") {
  Get-ChildItem -Recurse "${env:HomeDrive}${env:HomePath}/aliases" -Include *.ps1, *.psm1 |
  Foreach-Object {
    $folder = $_.Directory.Name;
    $ext = [IO.Path]::GetExtension($_.Name)

    if ($ext -eq ".ps1" -and $folder -ne "commands") {
      . $_.FullName
    }

    if ($ext -eq ".psm1" -and $folder -ne "commands") {
      Remove-Module -ErrorAction SilentlyContinue $_.FullName
      Import-Module $_.FullName -DisableNameChecking
    }
  }
}

try {
  mise activate pwsh | Out-String | Invoke-Expression
}
catch {}


## ENV
. ~/env.ps1
