function Install() {
  Set-Location $PSScriptRoot

  # Create or refresh a symlink at $Path pointing to $Target.
  # Idempotent: removes any existing file/dir/link before linking.
  function New-Link($Path, $Target) {
    $parent = Split-Path -Parent $Path
    if ($parent -and !(Test-Path $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path $Path) {
      $item = Get-Item $Path -Force
      if ($item.LinkType) {
        # Symlink or junction — delete just the link, never recurse into target
        $item.Delete()
      } elseif ($item.PSIsContainer) {
        Remove-Item -Recurse -Force $Path
      } else {
        Remove-Item -Force $Path
      }
    }
    New-Item -Path $Path -ItemType SymbolicLink -Value $Target | Out-Null
  }

  $home_ = "${env:HOMEDRIVE}${env:HOMEPATH}"

  # PowerShell profiles
  $baseProfile = Join-Path $home_ "profile.ps1"
  New-Link $baseProfile (Join-Path $PSScriptRoot "windows\profile.ps1")
  New-Link (Join-Path $home_ "env.ps1") (Join-Path $PSScriptRoot "windows\env.ps1")

  $docs = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell"
  $powershellProfile = Join-Path $docs "Microsoft.PowerShell_profile.ps1"
  $powershellISEProfile = Join-Path $docs "Microsoft.PowerShellISE_profile.ps1"
  New-Link $powershellProfile (Join-Path $PSScriptRoot "windows\Microsoft.PowerShell_profile.ps1")
  New-Link $powershellISEProfile (Join-Path $PSScriptRoot "windows\Microsoft.PowerShellISE_profile.ps1")

  # Link .copilot instructions folder to ~/.copilot/instructions
  New-Link (Join-Path $home_ ".copilot\instructions") (Join-Path $PSScriptRoot "common\.copilot\instructions")

  # Link ~/.claude config files/folders to dotfiles versions
  $claudeDir = Join-Path $home_ ".claude"
  New-Link (Join-Path $claudeDir "CLAUDE.md") (Join-Path $PSScriptRoot "common\.claude\CLAUDE.md")
  New-Link (Join-Path $claudeDir "settings.json") (Join-Path $PSScriptRoot "common\.claude\settings.json")
  New-Link (Join-Path $claudeDir "skills") (Join-Path $PSScriptRoot "common\.claude\skills")

  # Seed local config.toml from the example, then link ~/.codex config to dotfiles versions
  $codexConfig = Join-Path $PSScriptRoot "common\.codex\config.toml"
  $codexConfigExample = Join-Path $PSScriptRoot "common\.codex\config.example.toml"
  if (!(Test-Path $codexConfig)) {
    Copy-Item -Path $codexConfigExample -Destination $codexConfig
  }

  $codexDir = Join-Path $home_ ".codex"
  New-Link (Join-Path $codexDir "AGENTS.md") (Join-Path $PSScriptRoot "common\.codex\AGENTS.md")
  New-Link (Join-Path $codexDir "config.toml") (Join-Path $PSScriptRoot "common\.codex\config.toml")
  New-Link (Join-Path $codexDir "skills") (Join-Path $PSScriptRoot "common\.codex\skills")

  # Link ~/.config/mise/config.toml to dotfiles version
  New-Link (Join-Path $home_ ".config\mise\config.toml") (Join-Path $PSScriptRoot "common\.config\mise\config.toml")

  # Aliases and gitconfig
  New-Link (Join-Path $home_ "aliases\dotfiles") (Join-Path $PSScriptRoot "windows\aliases")
  New-Link (Join-Path $home_ ".gitconfig") (Join-Path $PSScriptRoot "common\.gitconfig")

  # Need to create a task to run startup.cmd in TaskScheduler as admin
  New-Link "${env:HOMEDRIVE}\System\startup.cmd" (Join-Path $PSScriptRoot "windows\startup\startup.cmd")
  New-Link "${env:HOMEDRIVE}\System\startup.ps1" (Join-Path $PSScriptRoot "windows\startup\startup.ps1")
  New-Link "C:\System\Startup" (Join-Path $PSScriptRoot "windows\startup-files")

  Write-Host ""
  Write-Host "Base profile linked to $baseProfile"
  Write-Host "Powershell profile linked to $powershellProfile"
  Write-Host "Powershell ISE profile linked to $powershellISEProfile"
  Write-Host "Aliases linked to ~/aliases/dotfiles"
  Write-Host "Git config linked to ~/.gitconfig"

  Write-Host " ======= NEXT ======= "
  Write-Host " - Need to create a task to run startup.cmd in TaskScheduler as admin"
  Write-Host " - Install oh-my-posh and fonts"
  Write-Host " ======= /NEXT ======= "

  Write-Host ""
  Write-Host -ForegroundColor Green "Successfully installed!"
}

Install
