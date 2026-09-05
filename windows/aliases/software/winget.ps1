function B-Software-Update-GitHubCopilot() {
  $id = 'GitHub.Copilot'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-7Zip() {
  $id = '7zip.7zip'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-Brave() {
  $id = 'Brave.Brave'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-Firefox() {
  $id = 'Mozilla.Firefox'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-qTorrent() {
  $id = 'qBittorrent.qBittorrent'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-Mise() {
  $id = 'jdx.mise'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-Slack() {
  $id = 'SlackTechnologies.Slack'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function B-Software-Update-ProtonVPN() {
  $id = 'Proton.ProtonVPN'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}
