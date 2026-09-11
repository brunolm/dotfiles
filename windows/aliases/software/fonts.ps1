# oh-my-posh registers downloaded fonts under HKCU, and Windows Terminal does not reliably
# enumerate per-user fonts. Moving them into the machine store is what makes the glyphs show up.
# $FamilyPrefix is the patched family name, which rarely matches the archive name: the
# CascadiaCode archive installs as CaskaydiaCove.
function B-Software-Install-NerdFont {
  param(
    [string]$Font = 'CascadiaCode',
    [string]$FamilyPrefix = 'CaskaydiaCove'
  )

  if (Get-FontRegistration -FamilyPrefix $FamilyPrefix -Scope Machine) {
    Write-Host "$FamilyPrefix is already installed for all users." -ForegroundColor DarkGray
    return
  }

  if (!(Get-FontRegistration -FamilyPrefix $FamilyPrefix -Scope User)) {
    if (!(Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
      throw "oh-my-posh not found; it is what downloads the Nerd Font archives."
    }
    Write-Host "Downloading $Font..." -ForegroundColor Cyan
    oh-my-posh font install $Font
  }

  Move-UserFontToMachine -FamilyPrefix $FamilyPrefix
}

function Get-FontRegistration {
  param(
    [Parameter(Mandatory)][string]$FamilyPrefix,
    [Parameter(Mandatory)][ValidateSet('User', 'Machine')][string]$Scope
  )

  $key = Get-ItemProperty (Get-FontHive $Scope) -ErrorAction SilentlyContinue
  if (!$key) { return @() }
  return @($key.PSObject.Properties | Where-Object { $_.Name -like "$FamilyPrefix*" })
}

# Registry value names carry the family plus the style ("CaskaydiaCove NF Bold (TrueType)"), and
# the value is a bare filename once the font lives in the machine store.
function Move-UserFontToMachine {
  param([Parameter(Mandatory)][string]$FamilyPrefix)

  Initialize-FontInterop
  $dest = Join-Path $env:SystemRoot 'Fonts'
  $moved = 0

  foreach ($font in Get-FontRegistration -FamilyPrefix $FamilyPrefix -Scope User) {
    if (!(Test-Path -LiteralPath $font.Value)) { continue }

    $target = Join-Path $dest (Split-Path $font.Value -Leaf)
    Copy-Item -LiteralPath $font.Value -Destination $target -Force
    New-ItemProperty -Path (Get-FontHive Machine) -Name $font.Name -Value (Split-Path $target -Leaf) -PropertyType String -Force | Out-Null
    [void][Dotfiles.Fonts]::AddFontResource($target)

    Remove-ItemProperty -Path (Get-FontHive User) -Name $font.Name -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $font.Value -Force -ErrorAction SilentlyContinue
    $moved++
  }

  # Running apps cache the font list; WM_FONTCHANGE is what tells them to re-enumerate.
  $result = [IntPtr]::Zero
  [void][Dotfiles.Fonts]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$result)

  Write-Host "Installed $moved $FamilyPrefix font files for all users." -ForegroundColor Green
}

function Get-FontHive([ValidateSet('User', 'Machine')][string]$Scope) {
  $root = if ($Scope -eq 'User') { 'HKCU:' } else { 'HKLM:' }
  return "$root\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
}

function Initialize-FontInterop {
  if ('Dotfiles.Fonts' -as [type]) { return }

  Add-Type -Namespace Dotfiles -Name Fonts -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResource(string path);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
'@
}
