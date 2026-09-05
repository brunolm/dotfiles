# Installs everything through the B-Software-* aliases so install and update share one code
# path. GitHub CLI goes first: the PowerShell and winget aliases use gh to date releases.
# git is not here: the README installs it first so this repo can be cloned at all.
$steps = @(
  { B-Software-Update-GitHubCLI }
  { B-Software-Update-Powershell }
  { B-Software-Update-GnuPG }
  { B-Software-Update-FFmpeg }
  { B-Software-Update-ImageMagick }

  { B-Software-Update-Brave }
  { B-Software-Update-Firefox }
  { B-Software-Update-Chrome }

  { B-Software-Update-PowerToys }
  { B-Software-Update-AutoHotkey }
  { B-Software-Update-ShareX }
  { B-Software-Update-Slack }
  { B-Software-Update-OBS }
  { B-Software-Update-WhatsApp }
  { B-Software-Update-VSCode }
  { B-Software-Update-CopyQ }
  { B-Software-Configure-CopyQ }

  # Gaming
  { B-Software-Update-Discord }
  { B-Software-Update-Steam }
)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (!([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run from an elevated PowerShell; the installers need admin."
  return
}

Get-ChildItem (Join-Path $PSScriptRoot 'windows\aliases\software\*.ps1') | ForEach-Object { . $_.FullName }

# A fresh machine has nothing to lose to a brand-new build, so skip the build-age prompts.
$global:BSoftwareMinAgeHours = 0
try {
  foreach ($step in $steps) {
    $label = $step.ToString().Trim()
    Write-Host ""
    Write-Host "### $label" -ForegroundColor Cyan
    try {
      & $step
    }
    catch {
      Write-Warning "$label failed: $($_.Exception.Message)"
    }
  }
}
finally {
  Remove-Variable BSoftwareMinAgeHours -Scope Global -ErrorAction SilentlyContinue
}
