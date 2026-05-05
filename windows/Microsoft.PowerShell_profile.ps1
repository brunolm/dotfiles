try {
    Set-ExecutionPolicy RemoteSigned
} catch { }

$HomeProfile = "${env:HomeDrive}${env:HomePath}\profile.ps1"
if (Test-Path -LiteralPath $HomeProfile -ErrorAction SilentlyContinue) {
  . $HomeProfile
}

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
