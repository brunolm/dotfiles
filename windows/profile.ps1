try {
  Set-ExecutionPolicy RemoteSigned
}
catch {}

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

if ($IsInteractiveShell) {
  try {
    # $host.UI.RawUI.ForegroundColor = "White";
    # $host.UI.RawUI.BackgroundColor = "Black";
    # Set-Location D:\
    # Clear-Host
    oh-my-posh --init --shell pwsh --config C:\BrunoLM\Projects\dotfiles\windows\_brunolm.omp.json | Invoke-Expression
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

if ($IsInteractiveShell) {
  Import-Module posh-git
  Import-Module -Name Terminal-Icons
}
##

Set-Alias -Name wf -Value "C:\Users\bruno\AppData\Local\nvs\default\wf.ps1"

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
