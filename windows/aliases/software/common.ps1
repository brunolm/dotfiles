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
