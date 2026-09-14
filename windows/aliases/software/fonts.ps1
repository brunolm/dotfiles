# Nerd Fonts v3 registers the patched families under the Win32 names CaskaydiaCove NF (icons may
# span two cells) and CaskaydiaCove NFM (icons squeezed into one cell); the Windows Terminal profile
# asks for the former. The Material Design icons live at U+F0001-F1AF0, which is where
# _brunolm.omp.json draws them from, so anything older than v3.0.0 blanks those glyphs.
# The files come from the GitHub release rather than `oh-my-posh font install` so the version stays
# pinned and the fonts land in the machine store instead of the per-user one.
function B-Software-Install-NerdFont {
  param(
    [string]$Tag = 'v3.5.1',
    [string]$FamilyPrefix = 'CaskaydiaCove',
    [string[]]$Families = @('CaskaydiaCoveNerdFont', 'CaskaydiaCoveNerdFontMono'),
    [string[]]$Styles = @(
      'Regular', 'Italic', 'Bold', 'BoldItalic',
      'SemiBold', 'SemiBoldItalic', 'SemiLight', 'SemiLightItalic',
      'Light', 'LightItalic', 'ExtraLight', 'ExtraLightItalic'
    )
  )

  $files = foreach ($family in $Families) { foreach ($style in $Styles) { "$family-$style.ttf" } }

  $current = @(Get-FontRegistration -FamilyPrefix $FamilyPrefix -Scope Machine)
  if (!(Compare-Object @($current.Value) @($files))) {
    Write-Host "$FamilyPrefix $Tag is already installed for all users." -ForegroundColor DarkGray
    return
  }

  # Another release registers the same family names a second time, and GDI then resolves
  # CaskaydiaCove NF to whichever of the two files it enumerates first.
  Uninstall-Font -FamilyPrefix $FamilyPrefix

  Install-FontFromArchive -Url "https://github.com/ryanoasis/nerd-fonts/releases/download/$Tag/CascadiaCode.zip" -Files $files -Label "$FamilyPrefix $Tag"
}

# Caskaydia Cove is the Cascadia Code fork with the RFN removed; it carries no Nerd Font glyphs, so
# it coexists with the CaskaydiaCove NF family rather than replacing it. Upstream publishes no
# releases, so the TTFs come straight from the default branch.
function B-Software-Install-CaskaydiaCove {
  param(
    [string[]]$Styles = @('Regular', 'Bold', 'SemiBold', 'Medium', 'Light', 'ExtraLight'),
    [string]$BaseUrl = 'https://raw.githubusercontent.com/eliheuer/caskaydia-cove/master/fonts/ttf'
  )

  if (Get-FontRegistration -FamilyPrefix 'Caskaydia Cove' -Scope Machine) {
    Write-Host "Caskaydia Cove is already installed for all users." -ForegroundColor DarkGray
    return
  }

  $sources = [ordered]@{}
  foreach ($style in $Styles) {
    $file = "CaskaydiaCove-$style.ttf"
    $sources[$file] = "$BaseUrl/$file"
  }

  Install-FontFromUrl -Sources $sources -Label 'Caskaydia Cove'
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

# Drops the family from both scopes: oh-my-posh registers under HKCU with an absolute path, the
# machine store under HKLM with a bare filename. A file another process is still using stays on
# disk, but removing the registration is what stops GDI from enumerating it.
function Uninstall-Font {
  param([Parameter(Mandatory)][string]$FamilyPrefix)

  Initialize-FontInterop
  $removed = 0

  foreach ($scope in 'Machine', 'User') {
    foreach ($font in Get-FontRegistration -FamilyPrefix $FamilyPrefix -Scope $scope) {
      $path = if (Split-Path $font.Value -IsAbsolute) { $font.Value } else { Join-Path (Join-Path $env:SystemRoot 'Fonts') $font.Value }

      [void][Dotfiles.Fonts]::RemoveFontResource($path)
      Remove-ItemProperty -Path (Get-FontHive $scope) -Name $font.Name -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
      $removed++
    }
  }

  if ($removed) { Write-Host "Removed $removed $FamilyPrefix font files from the previous install." -ForegroundColor DarkGray }
}

# $Sources maps each installed file name to its download URL.
function Install-FontFromUrl {
  param(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Sources,
    [Parameter(Mandatory)][string]$Label
  )

  Initialize-FontInterop
  $stage = Join-Path ([IO.Path]::GetTempPath()) "b-fonts-$PID"
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  try {
    foreach ($file in $Sources.Keys) {
      Write-Host "Downloading $file..." -ForegroundColor Cyan
      Invoke-WebRequest -Uri $Sources[$file] -OutFile (Join-Path $stage $file) -UseBasicParsing
    }

    # Every download finishes before the first Get-FontEntryName call: reading font metadata
    # between downloads leaves the WPF font cache unable to open any later file.
    foreach ($file in $Sources.Keys) {
      $path = Join-Path $stage $file
      Install-MachineFontFile -Path $path -Entry (Get-FontEntryName -Path $path)
    }
  }
  finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }

  Publish-FontChange
  Write-Host "Installed $($Sources.Count) $Label font files for all users." -ForegroundColor Green
}

# $Files lists the archive entries to install; the rest of the archive is ignored.
function Install-FontFromArchive {
  param(
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string[]]$Files,
    [Parameter(Mandatory)][string]$Label
  )

  Initialize-FontInterop
  $stage = Join-Path ([IO.Path]::GetTempPath()) "b-fonts-$PID"
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  try {
    $archive = Join-Path $stage 'fonts.zip'
    Write-Host "Downloading $Url..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing
    Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force

    foreach ($file in $Files) {
      $path = Join-Path $stage $file
      if (!(Test-Path -LiteralPath $path)) { throw "$file is missing from $Url" }
      Install-MachineFontFile -Path $path -Entry (Get-FontEntryName -Path $path)
    }
  }
  finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }

  Publish-FontChange
  Write-Host "Installed $($Files.Count) $Label font files for all users." -ForegroundColor Green
}

# GDI keys the font store by the Win32 family plus face ("CaskaydiaCove NF Regular"), which for
# patched and split-weight families differs from the typographic name the file advertises. The
# suffix follows the outline format: CFF files register as (OpenType), the rest as (TrueType).
function Get-FontEntryName {
  param([Parameter(Mandatory)][string]$Path)

  Add-Type -AssemblyName PresentationCore
  $glyphs = [Windows.Media.GlyphTypeface]::new([uri]$Path)
  $family = $glyphs.Win32FamilyNames.Values | Select-Object -First 1
  $face = $glyphs.Win32FaceNames.Values | Select-Object -First 1
  $format = if ([IO.Path]::GetExtension($Path) -ieq '.otf') { 'OpenType' } else { 'TrueType' }

  return "$family $face ($format)"
}

# $Entry is the registry value name ("CaskaydiaCove NF Regular (OpenType)"); the value itself is a
# bare filename once the font lives in the machine store. Requires Initialize-FontInterop.
function Install-MachineFontFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Entry
  )

  $target = Join-Path (Join-Path $env:SystemRoot 'Fonts') (Split-Path $Path -Leaf)
  Copy-Item -LiteralPath $Path -Destination $target -Force
  New-ItemProperty -Path (Get-FontHive Machine) -Name $Entry -Value (Split-Path $target -Leaf) -PropertyType String -Force | Out-Null
  [void][Dotfiles.Fonts]::AddFontResource($target)
}

# Running apps cache the font list; WM_FONTCHANGE is what tells them to re-enumerate.
function Publish-FontChange {
  $result = [IntPtr]::Zero
  [void][Dotfiles.Fonts]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$result)
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

[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern bool RemoveFontResource(string path);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
'@
}
