function Discord-Restart() {
  $updater = "$env:LOCALAPPDATA\Discord\Update.exe"
  if (!(Test-Path $updater)) {
    Write-Host "Discord updater not found at $updater" -ForegroundColor Red
    return
  }

  $procs = @(Get-Process Discord -ErrorAction SilentlyContinue)
  if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $procs.Id -Timeout 10 -ErrorAction SilentlyContinue
    Write-Host "Stopped $($procs.Count) Discord process(es)." -ForegroundColor DarkGray
  }

  # Squirrel install: Update.exe resolves the current app-x.y.z folder. Launching
  # Discord.exe directly pins to a build that self-updates out from under the path.
  Start-Process $updater -ArgumentList "--processStart", "Discord.exe"
  Write-Host "Discord restarted." -ForegroundColor Green
}
