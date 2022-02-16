function Install() {
  $baseProfile = "${env:HOMEDRIVE}${env:HOMEPATH}\profile.ps1";
  Remove-Item $baseProfile;
  New-Item -Path $baseProfile -ItemType SymbolicLink -Value ".\windows\profile.ps1";
  New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\env.ps1" -ItemType SymbolicLink -Value ".\windows\env.ps1";

  $docs = [Environment]::GetFolderPath("MyDocuments");
  $docs = (Join-Path $docs "WindowsPowerShell");

  $powershellProfile = (Join-Path $docs "Microsoft.PowerShell_profile.ps1");
  $powershellISEProfile = (Join-Path $docs "Microsoft.PowerShellISE_profile.ps1");

  Remove-Item $powershellProfile;
  Remove-Item $powershellISEProfile;
  New-Item -Path $powershellProfile -ItemType SymbolicLink -Value ".\windows\Microsoft.PowerShell_profile.ps1";
  New-Item -Path $powershellISEProfile -ItemType SymbolicLink -Value ".\windows\Microsoft.PowerShellISE_profile.ps1";

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases")) {
    mkdir "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\";
  }

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\dotfiles")) {
    New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\dotfiles" -ItemType SymbolicLink -Value ".\windows\aliases";
  }

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\.gitconfig")) {
    New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\.gitconfig" -ItemType SymbolicLink -Value ".\common\.gitconfig";
  }

  Write-Host ""
  Write-Host "Base profile linked to $baseProfile";
  Write-Host "Powershell profile linked to $powershellProfile";
  Write-Host "Powershell ISE profile linked to $powershellISEProfile";
  Write-Host "Aliases linked to ~/aliases/dotfiles";
  Write-Host "Git config linked to ~/aliases/dotfiles";
  Write-Host ""
  Write-Host -ForegroundColor Green "Successfully installed!"
}

Install
