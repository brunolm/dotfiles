try {
    Set-ExecutionPolicy RemoteSigned
} catch { }
#cd D:\
#cls
#echo $Profile

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
Import-Module posh-git
# Import-Module PowerTab

##

if (Test-Path "${env:HomeDrive}${env:HomePath}") {
    Get-ChildItem -Recurse "${env:HomeDrive}${env:HomePath}/aliases" -Include *.ps1, *.psm1 |
        Foreach-Object {
            $ext = [IO.Path]::GetExtension($_.Name)

            if ($ext -eq ".ps1") {
              . $_.FullName
            }

            if ($ext -eq ".psm1") {
              Import-Module $_.FullName
            }
        }
}
