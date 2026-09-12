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
    Write-Host "  $Path -> $Target" -ForegroundColor DarkGray
  }

  function Step($message) {
    Write-Host ""
    Write-Host "== $message" -ForegroundColor Cyan
  }

  # CurrentUser scope keeps the modules with the profile that imports them, and works whether or
  # not this shell is elevated.
  function Install-ProfileModule($name) {
    if (Get-Module -ListAvailable -Name $name) {
      Write-Host "  $name already installed" -ForegroundColor DarkGray
      return
    }
    Write-Host "  installing $name" -ForegroundColor DarkGray
    Install-Module -Name $name -Scope CurrentUser -Force -AllowClobber
  }

  $home_ = "${env:HOMEDRIVE}${env:HOMEPATH}"

  # Persisted in the registry, so this is the one place that needs it — the profiles no longer
  # re-apply it on every shell. Bootstrapping with -ExecutionPolicy Bypass reaches here fine.
  Step "Setting the execution policy"
  Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
  Write-Host "  LocalMachine = $(Get-ExecutionPolicy -Scope LocalMachine)" -ForegroundColor DarkGray

  Step "Linking PowerShell profiles"
  $baseProfile = Join-Path $home_ "profile.ps1"
  New-Link $baseProfile (Join-Path $PSScriptRoot "windows\profile.ps1")

  $envScript = Join-Path $PSScriptRoot "windows\env.ps1"
  if (!(Test-Path $envScript)) {
    Write-Host "  seeding env.ps1 from env.example.ps1" -ForegroundColor DarkGray
    Copy-Item -Path (Join-Path $PSScriptRoot "windows\env.example.ps1") -Destination $envScript
  }
  New-Link (Join-Path $home_ "env.ps1") $envScript

  $myDocuments = [Environment]::GetFolderPath("MyDocuments")
  $docs = Join-Path $myDocuments "WindowsPowerShell"
  $powershellProfile = Join-Path $docs "Microsoft.PowerShell_profile.ps1"
  $powershellISEProfile = Join-Path $docs "Microsoft.PowerShellISE_profile.ps1"
  New-Link $powershellProfile (Join-Path $PSScriptRoot "windows\Microsoft.PowerShell_profile.ps1")
  New-Link $powershellISEProfile (Join-Path $PSScriptRoot "windows\Microsoft.PowerShellISE_profile.ps1")

  # PowerShell 7 reads Documents\PowerShell, not Documents\WindowsPowerShell. The ISE profile has
  # no counterpart there: the ISE is 5.1 only.
  $ps7Profile = Join-Path (Join-Path $myDocuments "PowerShell") "Microsoft.PowerShell_profile.ps1"
  New-Link $ps7Profile (Join-Path $PSScriptRoot "windows\Microsoft.PowerShell_profile.ps1")

  Step "Linking Windows Terminal settings"
  $wtSettings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
  if (Test-Path (Split-Path -Parent $wtSettings)) {
    New-Link $wtSettings (Join-Path $PSScriptRoot "windows\terminal\settings.json")
  } else {
    Write-Host "  Windows Terminal not installed; skipping" -ForegroundColor DarkGray
  }

  Step "Linking Copilot instructions"
  New-Link (Join-Path $home_ ".copilot\instructions") (Join-Path $PSScriptRoot "common\.copilot\instructions")

  Step "Linking Claude config"
  $claudeDir = Join-Path $home_ ".claude"
  New-Link (Join-Path $claudeDir "CLAUDE.md") (Join-Path $PSScriptRoot "common\.claude\CLAUDE.md")
  New-Link (Join-Path $claudeDir "settings.json") (Join-Path $PSScriptRoot "common\.claude\settings.json")
  New-Link (Join-Path $claudeDir "skills") (Join-Path $PSScriptRoot "common\.claude\skills")
  New-Link (Join-Path $claudeDir "hooks") (Join-Path $PSScriptRoot "common\.claude\hooks")

  Step "Linking Codex config"
  $codexConfig = Join-Path $PSScriptRoot "common\.codex\config.toml"
  $codexConfigExample = Join-Path $PSScriptRoot "common\.codex\config.example.toml"
  if (!(Test-Path $codexConfig)) {
    Write-Host "  seeding config.toml from config.example.toml" -ForegroundColor DarkGray
    Copy-Item -Path $codexConfigExample -Destination $codexConfig
  }

  $codexDir = Join-Path $home_ ".codex"
  New-Link (Join-Path $codexDir "AGENTS.md") (Join-Path $PSScriptRoot "common\.codex\AGENTS.md")
  New-Link (Join-Path $codexDir "config.toml") (Join-Path $PSScriptRoot "common\.codex\config.toml")
  New-Link (Join-Path $codexDir "skills") (Join-Path $PSScriptRoot "common\.codex\skills")

  Step "Linking Grok config"
  New-Link (Join-Path $home_ ".grok\config.toml") (Join-Path $PSScriptRoot "common\.grok\config.toml")

  Step "Linking mise config"
  New-Link (Join-Path $home_ ".config\mise\config.toml") (Join-Path $PSScriptRoot "common\.config\mise\config.toml")

  Step "Linking aliases and gitconfig"
  New-Link (Join-Path $home_ "aliases\dotfiles") (Join-Path $PSScriptRoot "windows\aliases")
  New-Link (Join-Path $home_ ".gitconfig") (Join-Path $PSScriptRoot "common\.gitconfig")

  Step "Linking startup scripts"
  New-Link "${env:HOMEDRIVE}\System\startup.cmd" (Join-Path $PSScriptRoot "windows\startup\startup.cmd")
  New-Link "${env:HOMEDRIVE}\System\startup.ps1" (Join-Path $PSScriptRoot "windows\startup\startup.ps1")
  New-Link "C:\System\Startup" (Join-Path $PSScriptRoot "windows\startup-files")

  Step "Installing cursor scheme"
  & (Join-Path $PSScriptRoot "windows\cursors\install-cursors.ps1")

  Step "Disabling Alt+Shift layout switch, Win+V clipboard history and Sticky Keys hotkeys"
  . (Join-Path $PSScriptRoot "windows\aliases\reg\hotkeys.ps1")
  B-Reg-Disable-AltShift
  Write-Host "  Alt+Shift unassigned (takes effect after sign-out)" -ForegroundColor DarkGray
  B-Reg-Disable-WinV
  Write-Host "  Win+V disabled (takes effect after Explorer restart)" -ForegroundColor DarkGray
  B-Reg-Disable-StickyKeys
  Write-Host "  Sticky Keys off and Shift x5 hotkey removed" -ForegroundColor DarkGray

  Step "Installing Oh My Posh"
  $ompPkg = "JanDeDobbeleer.OhMyPosh"
  $ompListed = winget list --id $ompPkg --exact --accept-source-agreements 2>$null | Select-String $ompPkg
  if ($ompListed) {
    Write-Host "  upgrading $ompPkg (if newer is available)" -ForegroundColor DarkGray
    winget upgrade --id $ompPkg --exact --silent --accept-source-agreements --accept-package-agreements
  } else {
    Write-Host "  installing $ompPkg" -ForegroundColor DarkGray
    winget install --id $ompPkg --exact --silent --accept-source-agreements --accept-package-agreements
  }

  # winget puts oh-my-posh on the registry PATH, which this shell started too early to see.
  . (Join-Path $PSScriptRoot "windows\aliases\software\common.ps1")
  Sync-SessionPath

  Step "Installing the CaskaydiaCove Nerd Font"
  # The Windows Terminal profile asks for CaskaydiaCove NF, and the oh-my-posh prompt draws
  # glyphs that only a patched Nerd Font carries.
  . (Join-Path $PSScriptRoot "windows\aliases\software\fonts.ps1")
  B-Software-Install-NerdFont

  Step "Installing the Caskaydia Cove font"
  B-Software-Install-CaskaydiaCove

  Step "Installing PowerShell modules"
  # PowerShell 5.1 talks to the gallery over TLS 1.2 only after this, and the first
  # Install-Module otherwise stops to ask for the NuGet provider.
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
  }
  Install-ProfileModule 'posh-git'
  Install-ProfileModule 'Terminal-Icons'

  Write-Host ""
  Write-Host " ======= NEXT ======= "
  Write-Host " - Need to create a task to run startup.cmd in TaskScheduler as admin"
  Write-Host " ======= /NEXT ======= "

  Write-Host ""
  Write-Host -ForegroundColor Green "Successfully installed!"
}

Install
