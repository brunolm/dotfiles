# Chocolatey's copyq package trails upstream by several major versions,
# so pull the latest release straight from GitHub.
function B-Software-Update-CopyQ() {
  $release = Invoke-RestMethod 'https://api.github.com/repos/hluk/CopyQ/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles' }
  $latest = $release.tag_name.TrimStart('v')

  if ((SoftwareCopyQ-InstalledVersion) -eq $latest) {
    Write-Host "CopyQ $latest already installed" -ForegroundColor DarkGray
    return
  }

  $asset = $release.assets | Where-Object { $_.name -like '*-setup.exe' } | Select-Object -First 1
  if (-not $asset) {
    Write-Error "No Windows installer found in CopyQ release $($release.tag_name)"
    return
  }

  $setup = Join-Path $env:TEMP $asset.name
  Write-Host "Downloading CopyQ $latest..." -ForegroundColor Cyan
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

  Write-Host "Installing..." -ForegroundColor Cyan
  Start-Process $setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait
  Remove-Item $setup -Force
  Write-Host "Done." -ForegroundColor Green
}

# Installs the Win+V toggle and the automatic command that moves
# password-looking clips to a Passwords tab and expires them.
function B-Software-Configure-CopyQ() {
  $copyq = Join-Path $env:ProgramFiles 'CopyQ\copyq.exe'
  if (-not (Test-Path $copyq)) {
    Write-Error "CopyQ not found at $copyq"
    return
  }

  $scripts = SoftwareCopyQ-ScriptsDir
  $configDir = Join-Path $env:APPDATA 'copyq'
  New-Item -ItemType Directory -Path $configDir -Force | Out-Null
  Copy-Item (Join-Path $scripts 'expire-secrets.js') $configDir -Force

  $setupScript = (Join-Path $scripts 'setup-commands.js') -replace '\\', '/'
  $loader = "var f = new File('$setupScript'); f.openReadOnly(); var src = str(f.readAll()); f.close(); eval(src)"

  & $copyq --start-server eval $loader
}

# copyq.exe ships without a version resource, so the uninstall entry is the only local record.
function SoftwareCopyQ-InstalledVersion() {
  $entries = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
  return ($entries | Where-Object { $_.DisplayName -like 'CopyQ*' } | Select-Object -First 1).DisplayVersion
}

# The scripts live in windows/copyq next to the aliases folder. In a shell the aliases are
# loaded through the ~/aliases/dotfiles link, so resolve the link before walking up.
function SoftwareCopyQ-ScriptsDir() {
  $aliases = Get-Item (Join-Path $PSScriptRoot '..')
  $real = if ($aliases.LinkTarget) { $aliases.LinkTarget } else { $aliases.FullName }
  return Join-Path (Split-Path $real) 'copyq'
}
