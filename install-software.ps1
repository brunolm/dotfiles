# git is not listed: the README installs it first so this repo can be cloned at all.
$packages = @(
  'powershell-core'
  'gnupg'
  'ffmpeg'
  'imagemagick'

  'powertoys'
  'autohotkey'
  'sharex'
  'slack'
  'obs-studio'
  'whatsapp'

  # Gaming
  'discord'
  'steam'

  # 'docker-desktop'
  # 'vercel'
)

# One choco call for every package: choco reads its config, refreshes the feed and scans what
# is installed once instead of once per package, and skips the ones already present.
function InstallSoftware() {
  if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found, installing it with winget" -ForegroundColor Yellow
    winget install --id Chocolatey.Chocolatey -e --accept-source-agreements --accept-package-agreements
    Write-Host "Open a new shell so choco is on the PATH, then run this script again." -ForegroundColor Yellow
    return $false
  }

  choco install @packages -y --no-progress
  return $true
}

# Same download-and-run path as the update alias, so install and update never drift apart.
# A fresh machine has nothing to lose to an unstable build, so the build-age guard is relaxed to 1h.
function InstallVSCodeInsiders() {
  . (Join-Path $PSScriptRoot 'windows\aliases\software\common.ps1')
  . (Join-Path $PSScriptRoot 'windows\aliases\software\vscode.ps1')
  B-Software-Update-VSCode -MinAgeHours 1
}

# Chocolatey's copyq package trails upstream by several major versions,
# so pull the latest release straight from GitHub.
function InstallCopyQ() {
  $release = Invoke-RestMethod 'https://api.github.com/repos/hluk/CopyQ/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles' }
  $latest = $release.tag_name.TrimStart('v')

  if ((InstalledCopyQVersion) -eq $latest) {
    Write-Host "CopyQ $latest already installed"
    return
  }

  $asset = $release.assets | Where-Object { $_.name -like '*-setup.exe' } | Select-Object -First 1
  if (-not $asset) {
    Write-Error "No Windows installer found in CopyQ release $($release.tag_name)"
    return
  }

  $setup = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest $asset.browser_download_url -OutFile $setup -UseBasicParsing

  $checksums = $release.assets | Where-Object { $_.name -eq 'checksums-sha512.txt' } | Select-Object -First 1
  if ($checksums) {
    $line = (Invoke-WebRequest $checksums.browser_download_url -UseBasicParsing).Content -split "`n" | Where-Object { $_ -match [regex]::Escape($asset.name) }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash $setup -Algorithm SHA512).Hash

    if ($expected -and $actual -ne $expected) {
      Remove-Item $setup -Force
      Write-Error "CopyQ installer checksum mismatch for $($asset.name)"
      return
    }
  }

  Start-Process $setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait
  Remove-Item $setup -Force
}

# copyq.exe ships without a version resource, so the uninstall entry is the only local record.
function InstalledCopyQVersion() {
  $entries = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
  return ($entries | Where-Object { $_.DisplayName -like 'CopyQ*' } | Select-Object -First 1).DisplayVersion
}

# Installs the Win+V toggle and the automatic command that moves
# password-looking clips to a Passwords tab and expires them.
function ConfigureCopyQ() {
  $copyq = Join-Path $env:ProgramFiles 'CopyQ\copyq.exe'
  if (-not (Test-Path $copyq)) {
    Write-Error "CopyQ not found at $copyq"
    return
  }

  $configDir = Join-Path $env:APPDATA 'copyq'
  New-Item -ItemType Directory -Path $configDir -Force | Out-Null
  Copy-Item (Join-Path $PSScriptRoot 'windows\copyq\expire-secrets.js') $configDir -Force

  $setupScript = (Join-Path $PSScriptRoot 'windows\copyq\setup-commands.js') -replace '\\', '/'
  $loader = "var f = new File('$setupScript'); f.openReadOnly(); var src = str(f.readAll()); f.close(); eval(src)"

  & $copyq --start-server eval $loader
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (!([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run from an elevated PowerShell; choco and the CopyQ installer need admin."
  return
}

if (InstallSoftware) {
  InstallVSCodeInsiders
  InstallCopyQ
  ConfigureCopyQ
}
