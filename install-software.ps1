function InstallSoftware() {
  choco install powershell-core -y

  choco install git -y
  choco install gnupg -y
  choco install ffmpeg -y
  choco install imagemagick -y

  choco install powertoys -y
  choco install autohotkey -y
  choco install sharex -y
  choco install slack -y
  choco install obs-studio -y
  choco install whatsapp -y

  # Gaming
  choco install discord -y
  choco install steam -y

  # choco install docker-desktop -y

  # choco install vercel -y
  # choco install vim -y
}

# Chocolatey's copyq package trails upstream by several major versions,
# so pull the latest release straight from GitHub.
function InstallCopyQ() {
  $release = Invoke-RestMethod 'https://api.github.com/repos/hluk/CopyQ/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles' }

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

InstallSoftware
InstallCopyQ
ConfigureCopyQ


# Install chocolatey
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
