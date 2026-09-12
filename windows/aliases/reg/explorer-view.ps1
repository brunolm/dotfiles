## B-Reg-Set-ExplorerView: makes every folder open in Details view sorted by type without grouping, with hidden files and file extensions visible; -DryRun reports without writing, -NoRestart skips the Explorer restart
function B-Reg-Set-ExplorerView {
  [CmdletBinding()]
  param(
    [switch]$DryRun,
    [switch]$NoRestart
  )

  $changed = 0

  Write-Host ""
  Write-Host "### explorer options" -ForegroundColor Cyan
  $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  foreach ($option in @(
      [pscustomobject]@{ Name = 'Hidden'; Value = 1 }
      [pscustomobject]@{ Name = 'HideFileExt'; Value = 0 }
    )) {
    $written = BRegExplorer-SetValue $advanced $option.Name $option.Value 'DWord' $DryRun
    $state = BRegExplorer-State $written $DryRun
    Write-Host ("  {0,-9} {1,-22} = {2}" -f $state, $option.Name, $option.Value) -ForegroundColor (BRegExplorer-Color $written)
    $changed += $written
  }

  Write-Host ""
  Write-Host "### saved folder views" -ForegroundColor Cyan
  $changed += BRegExplorer-ClearBags $DryRun

  Write-Host ""
  Write-Host "### default view per folder template" -ForegroundColor Cyan
  $values = BRegExplorer-ViewValues
  foreach ($template in (BRegExplorer-Templates)) {
    $path = "$(BRegExplorer-BagsPath)\AllFolders\Shell\$($template.Guid)"
    $written = 0
    foreach ($value in $values) {
      $written += BRegExplorer-SetValue $path $value.Name $value.Value $value.Type $DryRun
    }
    $state = BRegExplorer-State $written $DryRun
    Write-Host ("  {0,-9} {1,-22} {2}" -f $state, $template.Name, $template.Guid) -ForegroundColor (BRegExplorer-Color $written)
    $changed += $written
  }

  Write-Host ""
  if ($DryRun) {
    Write-Host "Dry run: nothing written." -ForegroundColor Yellow
    return
  }

  Write-Host "$changed setting(s) changed." -ForegroundColor Green
  if (!$changed -or $NoRestart) { return }
  Write-Host "Restarting Explorer so the new defaults take effect." -ForegroundColor DarkGray
  B-Reg-Restart-Explorer
}

# Returns 1 when the value had to be written (or would be, on a dry run), 0 when it already matched.
function BRegExplorer-SetValue($path, $name, $value, $type, $dryRun) {
  $current = (Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue).$name
  $same = if ($value -is [byte[]]) { ($current -join ',') -eq ($value -join ',') } else { "$current" -eq "$value" }
  if ($same) { return 0 }
  if ($dryRun) { return 1 }

  if (!(Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -LiteralPath $path -Name $name -Value $value -Type $type
  return 1
}

function BRegExplorer-State($written, $dryRun) {
  if (!$written) { return 'ok' }
  if ($dryRun) { return 'would set' }
  return 'set'
}

function BRegExplorer-Color($written) {
  if ($written) { return 'Green' }
  return 'DarkGray'
}

# A folder Explorer has already shown keeps the view saved in its own bag, which wins over the
# AllFolders defaults, so the saved bags have to go. Explorer rebuilds them from the defaults.
function BRegExplorer-ClearBags($dryRun) {
  $cleared = 0
  foreach ($path in @(
      (BRegExplorer-BagsPath)
      "$(Split-Path (BRegExplorer-BagsPath))\BagMRU"
      'HKCU:\Software\Microsoft\Windows\Shell\Bags'
      'HKCU:\Software\Microsoft\Windows\Shell\BagMRU'
    )) {
    if (!(Test-Path -LiteralPath $path)) {
      Write-Host ("  {0,-11} {1}" -f 'ok', $path) -ForegroundColor DarkGray
      continue
    }
    if (!$dryRun) { Remove-Item -LiteralPath $path -Recurse -Force }
    $state = if ($dryRun) { 'would clear' } else { 'cleared' }
    Write-Host ("  {0,-11} {1}" -f $state, $path) -ForegroundColor Green
    $cleared++
  }
  return $cleared
}

function BRegExplorer-BagsPath() {
  return 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags'
}

# Explorer keeps one default per folder-type template, so the view has to be written for each of
# them — a folder Windows decided is a Pictures folder ignores the generic default.
function BRegExplorer-Templates() {
  @(
    [pscustomobject]@{ Name = 'generic'; Guid = '{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}' }
    [pscustomobject]@{ Name = 'generic library'; Guid = '{80213E82-BCFD-4C4F-8817-BB27601267A9}' }
    [pscustomobject]@{ Name = 'documents'; Guid = '{7D49D726-3C21-4F05-99AA-FDC2C9474656}' }
    [pscustomobject]@{ Name = 'downloads'; Guid = '{885A186E-A440-4ADA-812B-DB871B942259}' }
    [pscustomobject]@{ Name = 'music'; Guid = '{94D6DDCC-4A68-4175-A374-BD584A510B78}' }
    [pscustomobject]@{ Name = 'music (details)'; Guid = '{43FED747-B357-468E-AE70-EE0CB0F46508}' }
    [pscustomobject]@{ Name = 'pictures'; Guid = '{B3690E58-E961-423B-B687-386EBFD83239}' }
    [pscustomobject]@{ Name = 'videos'; Guid = '{5FA96407-7E77-483C-AC93-691D05850DE8}' }
  )
}

# Mode is FVM_DETAILS and LogicalViewMode is FLVM_DETAILS; an empty GroupByKey next to GroupView 0
# is what Explorer itself writes for "no grouping".
function BRegExplorer-ViewValues() {
  @(
    [pscustomobject]@{ Name = 'Mode'; Value = 4; Type = 'DWord' }
    [pscustomobject]@{ Name = 'LogicalViewMode'; Value = 1; Type = 'DWord' }
    [pscustomobject]@{ Name = 'IconSize'; Value = 16; Type = 'DWord' }
    [pscustomobject]@{ Name = 'GroupView'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Name = 'GroupByKey:FMTID'; Value = '{00000000-0000-0000-0000-000000000000}'; Type = 'String' }
    [pscustomobject]@{ Name = 'GroupByKey:PID'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Name = 'GroupByDirection'; Value = 1; Type = 'DWord' }
    [pscustomobject]@{ Name = 'Sort'; Value = (BRegExplorer-SortBytes); Type = 'Binary' }
  )
}

# Sort is 16 reserved bytes, a column count, then per column a PROPERTYKEY (16-byte FMTID plus its
# property id) and a direction, 1 ascending. Both ids belong to FMTID_Storage: 4 is the type
# column, 10 the name — type first, name to break ties, which is what "sort by type" shows.
function BRegExplorer-SortBytes() {
  $storage = [guid]'B725F130-47EF-101A-A5F1-02608C9EEBAC'
  $bytes = [System.Collections.Generic.List[byte]]::new()
  $bytes.AddRange([byte[]]::new(16))
  $bytes.AddRange([BitConverter]::GetBytes([int]2))
  foreach ($propertyId in 4, 10) {
    $bytes.AddRange($storage.ToByteArray())
    $bytes.AddRange([BitConverter]::GetBytes([int]$propertyId))
    $bytes.AddRange([BitConverter]::GetBytes([int]1))
  }
  return $bytes.ToArray()
}
