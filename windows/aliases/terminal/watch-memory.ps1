function B-Terminal-Watch-MemoryHogs {
  param(
    [int]$MinMemoryMB = 500,
    [int]$RefreshSeconds = 2,
    [int]$WarnMemoryMB = 1024,
    [int]$CriticalWarnMemoryMB = 3072
  )

  $threshold = $MinMemoryMB * 1MB
  $warn = $WarnMemoryMB * 1MB
  $critical = $CriticalWarnMemoryMB * 1MB

  try {
    while ($true) {
      Clear-Host
      Write-Host "Processes using over $MinMemoryMB MB (warn >= $WarnMemoryMB MB, critical >= $CriticalWarnMemoryMB MB, refresh ${RefreshSeconds}s) - Ctrl+C to stop" -ForegroundColor Yellow
      Write-Host ("Updated: {0}" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
      Write-Host ''

      $rows = Get-Process |
        Where-Object { $_.WorkingSet64 -gt $threshold -and $_.ProcessName -ne 'Memory Compression' } |
        Sort-Object WorkingSet64 -Descending |
        ForEach-Object {
          [pscustomobject]@{
            PID_       = $_.Id
            Name       = $_.ProcessName
            MemoryMB   = [math]::Ceiling($_.WorkingSet64 / 1MB)
            CPU_s      = if ($_.CPU) { [math]::Round($_.CPU, 1) } else { 0 }
            _RawMemory = $_.WorkingSet64
          }
        }

      if (-not $rows) {
        Write-Host "(no processes above threshold)" -ForegroundColor DarkGray
      } else {
        $fmt = "{0,-7} {1,-30} {2,12} {3,10}"
        Write-Host ($fmt -f 'PID', 'Name', 'Memory(MB)', 'CPU(s)') -ForegroundColor Cyan
        Write-Host ($fmt -f '---', '----', '----------', '------') -ForegroundColor DarkCyan
        foreach ($r in $rows) {
          $color =
            if ($r._RawMemory -ge $critical) { 'Red' }
            elseif ($r._RawMemory -ge $warn) { 'Yellow' }
            else { 'White' }
          Write-Host ($fmt -f $r.PID_, $r.Name, $r.MemoryMB, $r.CPU_s) -ForegroundColor $color
        }
      }

      Start-Sleep -Seconds $RefreshSeconds
    }
  } finally {
    Write-Host "`nStopped watching." -ForegroundColor DarkGray
  }
}
