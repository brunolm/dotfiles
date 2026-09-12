# $global:BSoftwareMinAgeHours overrides the default minimum age for every caller; the install
# script sets it to 0 so a fresh machine takes whatever build is current without prompting.
function Confirm-BuildAge {
  param(
    [Parameter(Mandatory)][DateTime]$BuiltAt,
    [double]$MinAgeHours = $(if ($null -ne $global:BSoftwareMinAgeHours) { $global:BSoftwareMinAgeHours } else { 6 }),
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

function Get-WingetManifestDate {
  param([Parameter(Mandatory)][string]$PackageId)

  Assert-GitHubCLI
  $ver = ((winget show $PackageId --accept-source-agreements) | Select-String -Pattern '^Version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
  $parts = $PackageId.Split('.')
  $bucket = $parts[0].Substring(0, 1).ToLower()
  $path = "manifests/$bucket/" + ($parts -join '/') + "/$ver"
  $date = gh api "repos/microsoft/winget-pkgs/commits?path=$path&per_page=1" --jq '.[0].commit.committer.date'
  return [DateTime]$date
}

# gh dates every winget manifest and GitHub release here, and `gh api` needs a token, so an
# unauthenticated CLI fails the same way a missing one does.
function Assert-GitHubCLI {
  if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Sync-SessionPath
  }
  if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found. Run B-Software-Update-GitHubCLI, then 'gh auth login'."
  }

  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run 'gh auth login'."
  }
}

# $Request is splatted into Invoke-RestMethod. Hosts queried in a tight loop drop connections
# mid-request, so a single transport failure says nothing about the endpoint being reachable.
function Invoke-RestMethodWithRetry {
  param(
    [Parameter(Mandatory)][hashtable]$Request,
    [int]$MaxAttempts = 4,
    [double]$DelaySeconds = 1
  )

  for ($attempt = 1; ; $attempt++) {
    try {
      return Invoke-RestMethod @Request -ErrorAction Stop
    }
    catch {
      if ($attempt -ge $MaxAttempts) { throw }
      Start-Sleep -Seconds ($DelaySeconds * $attempt)
    }
  }
}

function Get-UrlLastModified {
  param([Parameter(Mandatory)][string]$Url)
  $head = Invoke-WebRequest $Url -Method Head -UseBasicParsing
  return [DateTime]::Parse($head.Headers.'Last-Modified')
}

# Installers write PATH to the registry, but a running shell keeps the copy it started with, so
# without this a tool installed by one step stays invisible to the next.
function Sync-SessionPath {
  $entries = @($env:Path -split ';' | Where-Object { $_ })

  foreach ($scope in 'Machine', 'User') {
    foreach ($entry in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';' | Where-Object { $_ })) {
      if ($entries | Where-Object { $_.TrimEnd('\') -ieq $entry.TrimEnd('\') }) { continue }
      $entries += $entry
    }
  }

  $env:Path = $entries -join ';'
}

# Persists $Directory to the user PATH and makes it usable in the running shell. The directory is
# created when missing so the entry never dangles.
function Add-UserPath {
  param([Parameter(Mandatory)][string]$Directory)

  New-Item -ItemType Directory -Force -Path $Directory | Out-Null

  $target = $Directory.TrimEnd('\')
  $entries = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
  if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $target })) {
    [Environment]::SetEnvironmentVariable('Path', (($entries + $Directory) -join ';'), 'User')
    Write-Host "Added $Directory to the user PATH." -ForegroundColor Green
  }

  Sync-SessionPath
}
