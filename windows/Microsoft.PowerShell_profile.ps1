# The execution policy is persisted in the registry (HKLM/HKCU ShellIds, shared by pwsh 7 and
# Windows PowerShell 5.1), so it survives reboots and does not belong in a profile. On a new
# machine, run this once from an elevated shell:
#   Set-ExecutionPolicy RemoteSigned

# install.ps1 links this to windows/profile.ps1, so a missing file is a broken install worth an error.
. "${env:HomeDrive}${env:HomePath}\profile.ps1"

# The Chocolatey profile costs ~175ms a shell and only carries the refreshenv alias and choco tab
# completion, so it loads on first use. Chocolatey's own alias shadows this function afterwards,
# since aliases outrank functions in command resolution.
function refreshenv {
  Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -Global
  Update-SessionEnvironment
}
