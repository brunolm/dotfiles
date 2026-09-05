## B-Backup-Path: zips the user PATH (path-user.txt) and machine PATH (path-machine.txt), unexpanded, one entry per line
function B-Backup-Path {
  [CmdletBinding()]
  param(
    [string]$Output = 'path-backup.zip',
    [switch]$DryRun
  )

  $scopes = @(
    @{ Name = 'user'; Key = 'HKCU:\Environment'; Scope = 'User' }
    @{ Name = 'machine'; Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; Scope = 'Machine' }
  )

  $staging = BBackup-NewStagingDir
  try {
    $files = foreach ($scope in $scopes) {
      $entries = BBackupPath-Entries $scope.Key
      Write-Host ""
      Write-Host "### $($scope.Scope) PATH ($($entries.Count) entries)" -ForegroundColor Cyan
      $entries | ForEach-Object { Write-Host "  $_" }

      $file = Join-Path $staging "path-$($scope.Name).txt"
      $lines = @(
        "# $($scope.Scope) PATH from $env:COMPUTERNAME on $(Get-Date -Format 'yyyy-MM-dd HH:mm'), unexpanded as stored in $($scope.Key)"
        "# Restore one entry with: [Environment]::SetEnvironmentVariable('Path', ([Environment]::GetEnvironmentVariable('Path', '$($scope.Scope)') + ';<entry>'), '$($scope.Scope)')"
      ) + $entries
      Set-Content -LiteralPath $file -Value $lines -Encoding utf8
      [pscustomobject]@{ Path = $file; Entry = "path-$($scope.Name).txt" }
    }

    Write-Host ""
    if ($DryRun) {
      Write-Host "Dry run: nothing written." -ForegroundColor Yellow
      return
    }
    $zip = BBackup-WriteZip $files $Output
    Write-Host "Wrote $zip" -ForegroundColor Green
  }
  finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Read straight from the registry without expanding so %USERPROFILE%-style entries survive.
function BBackupPath-Entries($key) {
  $value = (Get-Item -LiteralPath $key).GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  return @($value -split ';' | Where-Object { $_ })
}
