function Update-SW-GitHubCli() {
  # TODO: get GitHub CLI
}

function Update-SW-GitHubCopilot() {
  winget install GitHub.Copilot
}

function Update-SW-7Zip() {
  # TODO: get from github releases
}

function Update-SW-Chrome() {
  Invoke-WebRequest "http://dl.google.com/chrome/install/stable/chrome_installer.exe" -OutFile (join-path $env:TEMP chrome.exe);
  Start-Process (join-path $env:TEMP chrome.exe);
}
# TODO: add Brave, Firefox

function Update-SW-Node() {
  # get NVS from GitHub releases
}

function Update-SW-Steam() {
  Invoke-WebRequest "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -OutFile (join-path $env:TEMP steam.exe);
  Start-Process (join-path $env:TEMP steam.exe);
}

function Update-SW-VSCode() {
  $url = "https://update.code.visualstudio.com/latest/win32-x64-user/insider"
  $file = Join-Path $env:TEMP "VSCodeInsiders-latest-win-x64.exe"
  Write-Host "Downloading VS Code Insiders..." -ForegroundColor Cyan
  Invoke-WebRequest $url -OutFile $file
  Write-Host "Installing..." -ForegroundColor Cyan
  Start-Process $file -ArgumentList "/verysilent", "/mergetasks=!runcode" -Wait
  Write-Host "Done." -ForegroundColor Green
  code-insiders --version
}

function Update-SW-Powershell() {
  $asset = gh release view --repo PowerShell/PowerShell --json assets --jq '.assets[] | select(.name | test("win-x64.msi$")) | .url' | Select-Object -First 1
  $file = Join-Path $env:TEMP "PowerShell-latest-win-x64.msi"
  $log = Join-Path $env:TEMP "PowerShell-install.log"
  Invoke-WebRequest $asset -OutFile $file
  Start-Process msiexec.exe -ArgumentList "/i", $file, "/qn", "/norestart", "/l*v", $log -Wait
  Write-Output "Install log: $log"
}

function Update-SW-qTorrent() {
  # TODO: dl
}
