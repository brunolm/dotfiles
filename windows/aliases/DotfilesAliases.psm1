# Every alias file is dot-sourced from where it sits, so $PSScriptRoot keeps pointing at its own
# folder — several aliases resolve sibling files and repo paths through it.
foreach ($file in (Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter *.ps1)) {
  . $file.FullName
}

Export-ModuleMember -Function * -Alias *
