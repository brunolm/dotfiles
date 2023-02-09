function Install() {
  $baseProfile = "${env:HOMEDRIVE}${env:HOMEPATH}\profile.ps1";
  Remove-Item $baseProfile;
  New-Item -Path $baseProfile -ItemType SymbolicLink -Value (Resolve-Path ".\windows\profile.ps1");
  New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\env.ps1" -ItemType SymbolicLink -Value (Resolve-Path ".\windows\env.ps1");

  $docs = [Environment]::GetFolderPath("MyDocuments");
  $docs = (Join-Path $docs "WindowsPowerShell");

  $powershellProfile = (Join-Path $docs "Microsoft.PowerShell_profile.ps1");
  $powershellISEProfile = (Join-Path $docs "Microsoft.PowerShellISE_profile.ps1");

  Remove-Item $powershellProfile;
  Remove-Item $powershellISEProfile;
  New-Item -Path $powershellProfile -ItemType SymbolicLink -Value (Resolve-Path ".\windows\Microsoft.PowerShell_profile.ps1");
  New-Item -Path $powershellISEProfile -ItemType SymbolicLink -Value (Resolve-Path ".\windows\Microsoft.PowerShellISE_profile.ps1");

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases")) {
    mkdir "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\";
  }

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\dotfiles")) {
    New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\aliases\dotfiles" -ItemType SymbolicLink -Value (Resolve-Path ".\windows\aliases");
  }

  if (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\.gitconfig")) {
    New-Item -Path "${env:HOMEDRIVE}${env:HOMEPATH}\.gitconfig" -ItemType SymbolicLink -Value (Resolve-Path ".\common\.gitconfig");
  }

  # Need to create a task to run startup.cmd in TaskScheduler as admin
  New-Item -Path "${env:HOMEDRIVE}\System\startup.cmd" -ItemType SymbolicLink -Value (Resolve-Path ".\windows\startup\startup.cmd");
  New-Item -Path "${env:HOMEDRIVE}\System\startup.ps1" -ItemType SymbolicLink -Value (Resolve-Path ".\windows\startup\startup.ps1");

  New-Item -Path "C:\System\Startup" -ItemType SymbolicLink -Value (Resolve-Path ".\windows\startup-files\");

  Write-Host ""
  Write-Host "Base profile linked to $baseProfile";
  Write-Host "Powershell profile linked to $powershellProfile";
  Write-Host "Powershell ISE profile linked to $powershellISEProfile";
  Write-Host "Aliases linked to ~/aliases/dotfiles";
  Write-Host "Git config linked to ~/aliases/dotfiles";
  Write-Host " xxxxxxxxxxx Install oh-my-posh and fonts";
  Write-Host ""
  Write-Host -ForegroundColor Green "Successfully installed!"
}

Install
