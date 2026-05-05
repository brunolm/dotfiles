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

  # Link .copilot instructions folder to ~/.copilot/instructions
  $copilotDir = "${env:HOMEDRIVE}${env:HOMEPATH}\.copilot\instructions";
  New-Item -Path $copilotDir -ItemType SymbolicLink -Value (Resolve-Path ".\common\.copilot\instructions");

  # Copy ~/.claude config files/folders from dotfiles versions
  $claudeDir = "${env:HOMEDRIVE}${env:HOMEPATH}\.claude";
  if (!(Test-Path $claudeDir)) {
    mkdir $claudeDir | Out-Null;
  }
  if (Test-Path "$claudeDir\CLAUDE.md") { Remove-Item -Force "$claudeDir\CLAUDE.md"; }
  if (Test-Path "$claudeDir\settings.json") { Remove-Item -Force "$claudeDir\settings.json"; }
  if (Test-Path "$claudeDir\skills") { Remove-Item -Recurse -Force "$claudeDir\skills"; }
  Copy-Item -Path (Resolve-Path ".\common\.claude\CLAUDE.md") -Destination "$claudeDir\CLAUDE.md" -Force;
  Copy-Item -Path (Resolve-Path ".\common\.claude\settings.json") -Destination "$claudeDir\settings.json" -Force;
  Copy-Item -Path (Resolve-Path ".\common\.claude\skills") -Destination "$claudeDir\skills" -Recurse -Force;

  # Copy ~/.codex config files/folders from dotfiles versions
  $codexDir = "${env:HOMEDRIVE}${env:HOMEPATH}\.codex";
  if (!(Test-Path $codexDir)) {
    mkdir $codexDir | Out-Null;
  }
  if (Test-Path "$codexDir\AGENTS.md") { Remove-Item -Force "$codexDir\AGENTS.md"; }
  if (Test-Path "$codexDir\config.toml") { Remove-Item -Force "$codexDir\config.toml"; }
  if (Test-Path "$codexDir\skills") { Remove-Item -Recurse -Force "$codexDir\skills"; }
  Copy-Item -Path (Resolve-Path ".\common\.codex\AGENTS.md") -Destination "$codexDir\AGENTS.md" -Force;
  Copy-Item -Path (Resolve-Path ".\common\.codex\config.toml") -Destination "$codexDir\config.toml" -Force;
  Copy-Item -Path (Resolve-Path ".\common\.codex\skills") -Destination "$codexDir\skills" -Recurse -Force;

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

  Write-Host " ======= NEXT ======= "
  Write-Host " - Need to create a task to run startup.cmd in TaskScheduler as admin";
  Write-Host " - Install oh-my-posh and fonts";
  Write-Host " ======= /NEXT ======= "
  Write-Host ""

  Write-Host ""
  Write-Host -ForegroundColor Green "Successfully installed!"
}

Install
