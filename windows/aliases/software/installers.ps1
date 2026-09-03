function B-Software-Update-Chrome() {
  $url = "http://dl.google.com/chrome/install/stable/chrome_installer.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Chrome installer')) { return }
  $file = Join-Path $env:TEMP chrome.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

function B-Software-Update-Steam() {
  $url = "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Steam installer')) { return }
  $file = Join-Path $env:TEMP steam.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}
