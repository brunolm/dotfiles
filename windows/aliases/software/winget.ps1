function B-Software-Update-GitHubCopilot() { Software-WingetInstall 'GitHub.Copilot' }
function B-Software-Update-7Zip() { Software-WingetInstall '7zip.7zip' }
function B-Software-Update-Brave() { Software-WingetInstall 'Brave.Brave' }
function B-Software-Update-Firefox() { Software-WingetInstall 'Mozilla.Firefox' }
function B-Software-Update-qTorrent() { Software-WingetInstall 'qBittorrent.qBittorrent' }
function B-Software-Update-Slack() { Software-WingetInstall 'SlackTechnologies.Slack' }
function B-Software-Update-ProtonVPN() { Software-WingetInstall 'Proton.ProtonVPN' }

# WhatsApp ships only through the Microsoft Store, so there is no winget-pkgs manifest to date it
# against and the msstore source has to be named explicitly.
function B-Software-Update-WhatsApp() {
  winget install --id 9NKSQGP7F2NH --exact --source msstore --accept-source-agreements --accept-package-agreements
}

function Software-WingetInstall($id) {
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install --id $id --exact --accept-source-agreements --accept-package-agreements
  Sync-SessionPath
}
