function B-Software-Update-GitHubCLI() { Software-ChocoUpgrade 'gh' }
function B-Software-Update-GnuPG() { Software-ChocoUpgrade 'gnupg' }
function B-Software-Update-FFmpeg() { Software-ChocoUpgrade 'ffmpeg' }
function B-Software-Update-ImageMagick() { Software-ChocoUpgrade 'imagemagick' }
function B-Software-Update-PowerToys() { Software-ChocoUpgrade 'powertoys' }
function B-Software-Update-AutoHotkey() { Software-ChocoUpgrade 'autohotkey' }
function B-Software-Update-ShareX() { Software-ChocoUpgrade 'sharex' }
function B-Software-Update-OBS() { Software-ChocoUpgrade 'obs-studio' }
function B-Software-Update-WhatsApp() { Software-ChocoUpgrade 'whatsapp' }
function B-Software-Update-Discord() { Software-ChocoUpgrade 'discord' }

# choco upgrade installs the package when it is missing and updates it otherwise, so one
# verb covers both a fresh machine and routine maintenance.
function Software-ChocoUpgrade($package) {
  if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found, installing it with winget" -ForegroundColor Yellow
    winget install --id Chocolatey.Chocolatey -e --accept-source-agreements --accept-package-agreements
    throw "Chocolatey was just installed; open a new shell so choco is on the PATH and run again."
  }
  choco upgrade $package -y --no-progress
}
