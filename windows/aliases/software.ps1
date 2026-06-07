function Update-SW-GitHubCopilot() {
  $id = 'GitHub.Copilot'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-7Zip() {
  $id = '7zip.7zip'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Chrome() {
  $url = "http://dl.google.com/chrome/install/stable/chrome_installer.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Chrome installer')) { return }
  $file = Join-Path $env:TEMP chrome.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

function Update-SW-Brave() {
  $id = 'Brave.Brave'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Firefox() {
  $id = 'Mozilla.Firefox'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Steam() {
  $url = "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Steam installer')) { return }
  $file = Join-Path $env:TEMP steam.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

function Update-SW-VSCode() {
  $url = "https://code.visualstudio.com/sha/download?build=insider&os=win32-x64"
  $file = Join-Path $env:TEMP "VSCodeInsiders-latest-win-x64.exe"

  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'VS Code Insiders')) { return }

  Write-Host "Downloading VS Code Insiders..." -ForegroundColor Cyan
  Invoke-WebRequest $url -OutFile $file
  Write-Host "Installing..." -ForegroundColor Cyan
  Start-Process $file -ArgumentList "/verysilent", "/mergetasks=!runcode" -Wait
  Write-Host "Done." -ForegroundColor Green
  code-insiders --version
}

function Update-SW-VSCodeExtensions() {
  param([double]$MinAgeHours = 8)

  $editorVersion = [version](((code-insiders --version)[0]) -replace '-insider$', '')
  $preReleaseMode = Get-VSCodePreReleaseExtensions

  Write-Host "Checking installed VS Code extensions for updates..." -ForegroundColor Cyan
  $installed = code-insiders --list-extensions --show-versions

  foreach ($line in $installed) {
    if ($line -notmatch '^(.+)@(.+)$') { continue }
    $id = $Matches[1]
    $current = $Matches[2]
    $allowPreRelease = $preReleaseMode.ContainsKey($id.ToLower())

    $latest = Get-VSCodeExtensionLatest -ExtensionId $id -EditorVersion $editorVersion -AllowPreRelease:$allowPreRelease
    if (-not $latest) {
      Write-Host "  $id - no compatible release found, skipping." -ForegroundColor DarkGray
      continue
    }

    $hasUpdate = try { [version]$latest.Version -gt [version]$current } catch { $latest.Version -ne $current }
    if (-not $hasUpdate) {
      Write-Host "  $id - up to date ($current)." -ForegroundColor DarkGray
      continue
    }

    $ageHours = ((Get-Date).ToUniversalTime() - $latest.LastUpdated.ToUniversalTime()).TotalHours
    if ($ageHours -lt $MinAgeHours) {
      Write-Host ("  $id - {0} available but only {1:N1}h old, skipping." -f $latest.Version, $ageHours) -ForegroundColor Yellow
      continue
    }

    Write-Host ("  $id - updating {0} -> {1} ({2:N1}h old)..." -f $current, $latest.Version, $ageHours) -ForegroundColor Green
    $installArgs = @("--install-extension", "$id@$($latest.Version)", "--force")
    if ($allowPreRelease) { $installArgs += "--pre-release" }
    code-insiders @installArgs
  }

  Write-Host "Done." -ForegroundColor Green
}

function Update-SW-Powershell() {
  Write-Host "Checking latest PowerShell release..." -ForegroundColor Cyan
  $release = gh release view --repo PowerShell/PowerShell --json assets,publishedAt,tagName | ConvertFrom-Json
  $version = $release.tagName -replace '^v', ''
  Write-Host "Latest version: $version (published $([DateTime]$release.publishedAt))" -ForegroundColor Cyan

  $asset = ($release.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1).url
  if (-not (Confirm-BuildAge -BuiltAt ([DateTime]$release.publishedAt) -Label 'Release')) { return }

  $file = Join-Path $env:TEMP "PowerShell-latest-win-x64.msi"
  $log = Join-Path $env:TEMP "PowerShell-install.log"
  Write-Host "Downloading PowerShell $version..." -ForegroundColor Cyan
  Invoke-WebRequest $asset -OutFile $file
  Write-Host "Installing PowerShell $version..." -ForegroundColor Cyan
  Start-Process msiexec.exe -ArgumentList "/i", $file, "/qn", "/norestart", "/l*v", $log -Wait
  Write-Host "Done. Install log: $log" -ForegroundColor Green
}

function Update-SW-qTorrent() {
  $id = 'qBittorrent.qBittorrent'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Mise() {
  $id = 'jdx.mise'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Slack() {
  $id = 'SlackTechnologies.Slack'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Get-WingetManifestDate {
  param([Parameter(Mandatory)][string]$PackageId)

  $ver = ((winget show $PackageId) | Select-String -Pattern '^Version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
  $parts = $PackageId.Split('.')
  $bucket = $parts[0].Substring(0, 1).ToLower()
  $path = "manifests/$bucket/" + ($parts -join '/') + "/$ver"
  $date = gh api "repos/microsoft/winget-pkgs/commits?path=$path&per_page=1" --jq '.[0].commit.committer.date'
  return [DateTime]$date
}

function Get-UrlLastModified {
  param([Parameter(Mandatory)][string]$Url)
  $head = Invoke-WebRequest $Url -Method Head
  return [DateTime]::Parse($head.Headers.'Last-Modified')
}

function Get-VSCodePreReleaseExtensions {
  $file = Join-Path $env:USERPROFILE ".vscode-insiders\extensions\extensions.json"
  $map = @{}
  if (-not (Test-Path $file)) { return $map }

  foreach ($e in (Get-Content $file -Raw | ConvertFrom-Json)) {
    if ($e.metadata.preRelease) { $map[$e.identifier.id.ToLower()] = $true }
  }
  return $map
}

function Get-VSCodeExtensionLatest {
  param(
    [Parameter(Mandatory)][string]$ExtensionId,
    [version]$EditorVersion,
    [switch]$AllowPreRelease
  )

  # flags 17 = IncludeVersions (1) | IncludeVersionProperties (16); filterType 7 = ExtensionName
  $body = @{
    filters = @(@{ criteria = @(@{ filterType = 7; value = $ExtensionId }) })
    flags   = 17
  } | ConvertTo-Json -Depth 6

  $headers = @{
    'Accept'       = 'application/json;api-version=3.0-preview.1'
    'Content-Type' = 'application/json'
  }

  $resp = Invoke-RestMethod -Uri 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery' -Method Post -Body $body -Headers $headers
  $ext = $resp.results[0].extensions | Select-Object -First 1
  if (-not $ext) { return $null }

  # Versions are newest-first; pick the newest build the installed editor can run,
  # skipping pre-releases unless this extension is installed in pre-release mode.
  foreach ($v in $ext.versions) {
    $props = $v.properties
    if (-not $AllowPreRelease -and (($props | Where-Object { $_.key -eq 'Microsoft.VisualStudio.Code.PreRelease' }).value) -eq 'true') { continue }

    $engine = ($props | Where-Object { $_.key -eq 'Microsoft.VisualStudio.Code.Engine' }).value
    if ($EditorVersion -and -not (Test-VSCodeEngineMatch -Engine $engine -EditorVersion $EditorVersion)) { continue }

    return [PSCustomObject]@{
      Version     = $v.version
      LastUpdated = [DateTime]$v.lastUpdated
    }
  }

  return $null
}

function Test-VSCodeEngineMatch {
  param(
    [AllowEmptyString()][string]$Engine,
    [Parameter(Mandatory)][version]$EditorVersion
  )

  if (-not $Engine -or $Engine -eq '*') { return $true }
  if ($Engine -notmatch '(\d+)\.(\d+)(?:\.(\d+))?') { return $true }

  $patch = if ($Matches[3]) { $Matches[3] } else { '0' }
  return $EditorVersion -ge [version]"$($Matches[1]).$($Matches[2]).$patch"
}

function Confirm-BuildAge {
  param(
    [Parameter(Mandatory)][DateTime]$BuiltAt,
    [double]$MinAgeHours = 6,
    [string]$Label = 'Build'
  )

  $builtUtc = $BuiltAt.ToUniversalTime()
  $ageHours = ((Get-Date).ToUniversalTime() - $builtUtc).TotalHours

  if ($ageHours -ge $MinAgeHours) {
    Write-Host ("$Label is {0:N1}h old, proceeding." -f $ageHours) -ForegroundColor Cyan
    return $true
  }

  Write-Host ("$Label is only {0:N1}h old (built {1:u}). It may be unstable." -f $ageHours, $builtUtc) -ForegroundColor Yellow
  $answer = Read-Host "Install anyway? [y/N]"
  if ($answer -match '^(y|yes)$') { return $true }

  Write-Host "Aborted." -ForegroundColor Red
  return $false
}
