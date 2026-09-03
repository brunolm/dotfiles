# Lists the commands defined under the aliases folder, one section per subfolder.
# Public = name starts with "B-" or is an all-lowercase short alias; -All adds the helpers.
# A "## Name: text" comment right above a function becomes its description.
function B-Help {
  param(
    [Parameter(Position = 0)]
    [string]$Filter = '*',
    [switch]$All
  )

  $root = $PSScriptRoot
  $entries = Get-ChildItem -Path $root -Recurse -Include *.ps1 |
    Sort-Object FullName |
    ForEach-Object { BHelp-ScanFile $_ $root }

  if (!$All) {
    $entries = $entries | Where-Object { BHelp-IsPublic $_.Name }
  }

  $entries = $entries | Where-Object { $_.Name -like $Filter -or $_.Section -like $Filter }
  if (!$entries) {
    Write-Host "No aliases match '$Filter'." -ForegroundColor Yellow
    return
  }

  $width = ($entries | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum + 2
  foreach ($group in ($entries | Group-Object Section)) {
    Write-Host ""
    Write-Host "## $($group.Name)" -ForegroundColor Cyan
    foreach ($entry in ($group.Group | Sort-Object Name)) {
      BHelp-PrintEntry $entry $width
    }
  }
  Write-Host ""
}

function BHelp-ScanFile($file, $root) {
  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { return }

  $lines = Get-Content $file.FullName
  $relative = $file.DirectoryName.Substring($root.Length).TrimStart('\', '/')
  $section = if ($relative) { $relative -replace '[\\/]', '/' } else { 'general' }

  $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    Where-Object { !(BHelp-IsNested $_) }

  foreach ($fn in $functions) {
    [pscustomobject]@{
      Section     = $section
      Name        = $fn.Name
      Kind        = 'function'
      Description = BHelp-Description $fn $lines
      File        = $file.Name
    }
  }

  $aliases = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Set-Alias' }, $true)
  foreach ($cmd in $aliases) {
    $bound = BHelp-AliasArguments $cmd
    if (!$bound.Name) { continue }

    [pscustomobject]@{
      Section     = $section
      Name        = $bound.Name
      Kind        = 'alias'
      Description = "-> $($bound.Value)"
      File        = $file.Name
    }
  }
}

function BHelp-IsNested($fn) {
  $parent = $fn.Parent
  while ($parent) {
    if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $true }
    $parent = $parent.Parent
  }
  return $false
}

function BHelp-Description($fn, $lines) {
  $lineAbove = $fn.Extent.StartLineNumber - 2
  if ($lineAbove -ge 0 -and $lines[$lineAbove] -match '^##\s*(?:[\w-]+:\s*)?(.+)$') {
    return $Matches[1].Trim()
  }

  $params = @()
  if ($fn.Parameters) { $params = $fn.Parameters }
  elseif ($fn.Body.ParamBlock) { $params = $fn.Body.ParamBlock.Parameters }

  return ($params | ForEach-Object { $_.Name.VariablePath.UserPath } | ForEach-Object { "-$_" }) -join ' '
}

function BHelp-AliasArguments($cmd) {
  $result = @{ Name = $null; Value = $null }
  $elements = $cmd.CommandElements
  for ($i = 1; $i -lt $elements.Count - 1; $i++) {
    $element = $elements[$i]
    if ($element -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }

    $value = $elements[$i + 1].Extent.Text.Trim('"', "'")
    if ($element.ParameterName -eq 'Name') { $result.Name = $value }
    if ($element.ParameterName -eq 'Value') { $result.Value = $value }
  }
  return $result
}

function BHelp-IsPublic($name) {
  return $name -like 'B-*' -or $name -cnotmatch '[A-Z]'
}

function BHelp-PrintEntry($entry, $width) {
  $color = if ($entry.Kind -eq 'alias') { 'DarkGray' } else { 'Green' }
  Write-Host ("  {0,-$width}" -f $entry.Name) -ForegroundColor $color -NoNewline
  Write-Host ("{0,-22}" -f $entry.File) -ForegroundColor DarkGray -NoNewline
  Write-Host $entry.Description
}
