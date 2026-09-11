function B-Software-Update-Chrome() {
  $url = "http://dl.google.com/chrome/install/stable/chrome_installer.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Chrome installer')) { return }
  $file = Join-Path $env:TEMP chrome.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

# SteamSetup.exe is an NSIS installer, so /S is the silent switch. Steam still launches itself
# once the install finishes to pull the client update; there is no flag that suppresses that.
function B-Software-Update-Steam() {
  $url = "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Steam installer')) { return }
  $file = Join-Path $env:TEMP steam.exe
  Invoke-WebRequest $url -OutFile $file -UseBasicParsing
  Write-Host "Installing Steam..." -ForegroundColor Cyan
  Start-Process $file -ArgumentList '/S' -Wait
  Write-Host "Done." -ForegroundColor Green
}
