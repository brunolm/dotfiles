try {
    Set-ExecutionPolicy RemoteSigned
} catch { }

. "${env:HomeDrive}${env:HomePath}\profile.ps1"

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
