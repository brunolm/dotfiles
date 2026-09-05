## B-Backup-BrowserExtensions: zips the local settings stores of Brave, Edge and Chrome extensions (uBlock, Tampermonkey, Stylus, Dark Reader, ...) plus a restore.ps1; close the browsers first
function B-Backup-BrowserExtensions {
  [CmdletBinding()]
  param(
    [string]$Output = 'browser-extensions-backup.zip',
    [switch]$Force,
    [switch]$DryRun
  )

  $files = [System.Collections.Generic.List[object]]::new()
  $inventory = [System.Collections.Generic.List[string]]::new()
  $replaceDirs = [System.Collections.Generic.List[string]]::new()

  foreach ($browser in (BBackupExt-Browsers)) {
    if (!(Test-Path -LiteralPath $browser.UserData)) { continue }
    if (!$Force -and (Get-Process -Name $browser.Process -ErrorAction SilentlyContinue)) {
      Write-Warning "$($browser.Name) is running; close it or pass -Force to copy its stores anyway."
      continue
    }

    $profiles = Get-ChildItem -LiteralPath $browser.UserData -Directory | Where-Object { $_.Name -match '^(Default|Profile \d+)$' }
    foreach ($profile in $profiles) {
      foreach ($extension in (BBackupExt-Extensions $profile.FullName)) {
        if ((BBackupExt-ExcludedIds) -contains $extension.Id) { continue }
        $inventory.Add("$($browser.Name)`t$($profile.Name)`t$($extension.Id)`t$($extension.Name)")
        foreach ($store in $extension.Stores) {
          $replaceDirs.Add((BBackup-EntryName $store))
          foreach ($file in (Get-ChildItem -LiteralPath $store -Recurse -File -Force | Where-Object { $_.Name -ne 'LOCK' })) {
            $files.Add([pscustomobject]@{ Path = $file.FullName; Entry = (BBackup-EntryName $file.FullName) })
          }
        }
      }
    }
  }

  if (!$files.Count) {
    Write-Host "No extension data found." -ForegroundColor Yellow
    return
  }

  Write-Host ""
  foreach ($line in $inventory) { Write-Host "  $($line.Replace("`t", '  '))" -ForegroundColor Cyan }
  Write-Host ""
  $text = @{
    'extensions.tsv'   = "browser`tprofile`tid`tname`n" + ($inventory -join "`n")
    'replace-dirs.txt' = $replaceDirs -join "`n"
  }
  BBackup-HomeBackup $files $Output $DryRun $text
}

# Every installed extension that owns at least one data store in the profile. Stores left
# behind by removed extensions are skipped.
function BBackupExt-Extensions($profile) {
  $installed = BBackupExt-Installed $profile
  foreach ($id in ($installed.Keys | Sort-Object)) {
    $stores = BBackupExt-Stores $profile $id
    if (!$stores) { continue }
    [pscustomobject]@{ Id = $id; Name = (BBackupExt-Name $profile $id $installed[$id]); Stores = $stores }
  }
}

# Chromium splits extension records between Preferences and Secure Preferences.
function BBackupExt-Installed($profile) {
  $installed = @{}
  foreach ($name in 'Preferences', 'Secure Preferences') {
    $prefs = Get-Content -LiteralPath (Join-Path $profile $name) -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
    if (!$prefs -or !$prefs.extensions -or !$prefs.extensions.settings) { continue }
    foreach ($id in $prefs.extensions.settings.Keys) { $installed[$id] = $prefs.extensions.settings[$id] }
  }
  return $installed
}

function BBackupExt-Stores($profile, $id) {
  $stores = @(
    (Join-Path $profile "Local Extension Settings\$id"),
    (Join-Path $profile "Sync Extension Settings\$id")
  )
  $stores += @(Get-ChildItem -Path (Join-Path $profile "IndexedDB\chrome-extension_${id}_*") -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
  return @($stores | Where-Object { (Test-Path -LiteralPath $_) -and (Get-ChildItem -LiteralPath $_ -File -Force | Where-Object { $_.Name -ne 'LOCK' }) })
}

function BBackupExt-Name($profile, $id, $record) {
  $versions = Get-ChildItem -Path (Join-Path $profile "Extensions\$id") -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
  if (!$versions) {
    if ($record.path) { return "(unpacked: $($record.path))" }
    return '(no local package)'
  }

  $manifest = Get-Content -LiteralPath (Join-Path $versions[0].FullName 'manifest.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
  if (!$manifest) { return '(unreadable manifest)' }

  $name = [string]$manifest.name
  if ($name -notmatch '^__MSG_(.+)__$') { return $name }

  $key = $Matches[1]
  foreach ($locale in @($manifest.default_locale, 'en', 'en_US') | Where-Object { $_ }) {
    $messages = Get-Content -LiteralPath (Join-Path $versions[0].FullName "_locales\$locale\messages.json") -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
    if ($messages -and $messages[$key]) { return [string]$messages[$key].message }
  }
  return $name
}

function BBackupExt-Browsers() {
  return @(
    [pscustomobject]@{ Name = 'Brave'; Process = 'brave'; UserData = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
    [pscustomobject]@{ Name = 'Edge'; Process = 'msedge'; UserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
    [pscustomobject]@{ Name = 'Chrome'; Process = 'chrome'; UserData = "$env:LOCALAPPDATA\Google\Chrome\User Data" }
  )
}

# Bitwarden keeps a vault cache that is large and lives on the server anyway; the Claude
# extension only caches sessions.
function BBackupExt-ExcludedIds() {
  return @(
    'jbkfoedolllekgbhcbcoahefnbanhhlh', # Bitwarden (Edge store)
    'nngceckbapebfimnlniiiahkandclblb', # Bitwarden (Chrome store)
    'fcoeoabgfenejglbffodgkkbkcdhcgfn'  # Claude
  )
}
