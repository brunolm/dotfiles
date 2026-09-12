# The execution policy is persisted in the registry (HKLM/HKCU ShellIds, shared by pwsh 7 and
# Windows PowerShell 5.1), so it survives reboots and does not belong in a profile. On a new
# machine, run this once from an elevated shell:
#   Set-ExecutionPolicy RemoteSigned

# install.ps1 links this to windows/profile.ps1, so a missing file is a broken install worth an error.
. "${env:HomeDrive}${env:HomePath}\profile.ps1"

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
