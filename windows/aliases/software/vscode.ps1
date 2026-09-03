function B-Software-Update-VSCode() {
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

function B-Software-Update-VSCodeExtensions() {
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
