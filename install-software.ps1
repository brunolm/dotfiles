# Installs everything through the B-Software-* aliases so install and update share one code
# path. git is not here: the README installs it first so this repo can be cloned at all.
$steps = @(
  { B-Software-Update-Powershell }
  { B-Software-Update-GnuPG }
  { B-Software-Update-FFmpeg }
  { B-Software-Update-ImageMagick }

  # Codex needs npm, which comes from the node that mise installs.
  { B-Software-Update-Mise }
  { B-Software-Update-Claude }
  { B-Software-Update-Grok }
  { B-Software-Update-Codex }

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

# Almost every step below dates its download through gh — winget manifests and GitHub releases —
# and `gh api` needs a token, so the CLI is installed and signed in before the list runs.
function Initialize-GitHubCLI {
  Write-Host "### B-Software-Update-GitHubCLI" -ForegroundColor Cyan
  B-Software-Update-GitHubCLI

  if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is not on the PATH after installing it; open a new shell and run again."
  }

  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { return }

  Write-Host ""
  Write-Host "GitHub CLI is not signed in; the release lookups below need a token." -ForegroundColor Yellow
  gh auth login

  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is still not signed in. Run 'gh auth login' and start over."
  }
}

try {
  Initialize-GitHubCLI
}
catch {
  Write-Error $_.Exception.Message
  return
}

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
