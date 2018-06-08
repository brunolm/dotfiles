try {
    Set-ExecutionPolicy RemoteSigned
}
catch {}

try {
    $host.UI.RawUI.ForegroundColor = "White";
    $host.UI.RawUI.BackgroundColor = "Black";
    # Set-Location D:\
    Clear-Host
}
catch {}

function edit-profile {
  Write-Output $Profile
  code $Profile
}

function edit-aliases() {
  code $env:Home/aliases
}

function edit-hosts {
  Write-Output "C:\Windows\System32\drivers\etc\hosts"
  Start-Process -verb runas code "C:\Windows\System32\drivers\etc\hosts"
}

##
## Modules
#

## Update modules
# powershell -noprofile -command "Install-Module PSReadline -Force -SkipPublisherCheck"
# Update-Module posh-git

##
## Load modules
##
# Import-Module PSReadline
# Import-Module PowerTab
Import-Module posh-git
$global:GitPromptSettings.WorkingForegroundColor = "Red"

##

if (Test-Path "${env:HomeDrive}${env:HomePath}") {
    Get-ChildItem -Recurse "${env:HomeDrive}${env:HomePath}/aliases" -Include *.ps1, *.psm1 |
        Foreach-Object {
            $folder = $_.Directory.Name;
            $ext = [IO.Path]::GetExtension($_.Name)

            if ($ext -eq ".ps1" -and $folder -ne "commands") {
              . $_.FullName
            }

            if ($ext -eq ".psm1" -and $folder -ne "commands") {
              Remove-Module -ErrorAction SilentlyContinue $_.FullName
              Import-Module $_.FullName
            }
        }
}
