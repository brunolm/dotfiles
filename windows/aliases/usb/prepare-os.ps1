## B-USB-PrepareOS: prepares a Windows install USB for a fresh machine: prints the download/write steps, writes the edition picker (or -Edition Home|Pro|Education) and copies essentials.ps1 to the USB root so Git can be installed right after setup
function B-USB-PrepareOS {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Drive,
    [ValidateSet('Home', 'Pro', 'Education')]
    [string]$Edition
  )

  $letter = $Drive.TrimEnd(':', '\', '/')
  $root = "${letter}:\"
  BUsb-PrintSteps $letter $Edition

  if (!(Test-Path -LiteralPath "${root}sources" -PathType Container)) {
    Write-Host "$root has no sources folder yet. Write the ISO with Rufus (steps 1-3), then run this again." -ForegroundColor Yellow
    return
  }

  B-USB-Add-WindowsEditionPicker @PSBoundParameters
  Copy-Item -LiteralPath (BUsb-RepoFile 'windows\usb\essentials.ps1') -Destination $root -Force
  Write-Host "Copied essentials.ps1 to $root" -ForegroundColor Green
}

function BUsb-PrintSteps($letter, $Edition) {
  $rerun = "B-USB-PrepareOS $letter" + $(if ($Edition) { " -Edition $Edition" })
  $editionStep = if ($Edition) {
    "Setup installs Windows 11 $Edition without asking."
  } else {
    "Setup shows an edition picker. On 24H2+ media click 'Previous version of Setup' on the third screen if it does not."
  }
  Write-Host @"

Windows install USB on ${letter}:
  1. Install Rufus:            B-Software-Update-Rufus
  2. Download the ISO:         https://www.microsoft.com/en-US/software-download/windows11
                               section 'Download Windows 11 Disk Image (ISO) for x64 devices'
                               product 'Windows 11 (multi-edition ISO for x64 devices)', language 'English (United States)'
                               verify: (Get-FileHash <iso> -Algorithm SHA256).Hash matches the hash shown on the page
  3. Write it with Rufus:      Device = ${letter}:, Select = the ISO, Partition scheme = GPT, Target = UEFI (non CSM), Start
  4. Run this again:           $rerun
                               $editionStep
  5. Boot the new machine from the USB (F11 on the GE76, pick the UEFI: entry) and install.
  6. After setup, from an elevated PowerShell (installs Chocolatey, Git and clones dotfiles):
                               powershell -ExecutionPolicy Bypass -File ${letter}:\essentials.ps1
                               then in C:\BrunoLM\Projects\dotfiles run install.ps1 and install-software.ps1 (see README).

"@
}

# ~/aliases/dotfiles is a symlink to windows/aliases in the repo; resolve it to reach files outside the aliases tree.
function BUsb-RepoFile($relative) {
  $aliases = Get-Item -LiteralPath (Split-Path $PSScriptRoot)
  $real = if ($aliases.Target) { $aliases.Target } else { $aliases.FullName }
  $file = Join-Path (Split-Path (Split-Path $real)) $relative
  if (!(Test-Path -LiteralPath $file)) { throw "$file not found" }
  return $file
}
