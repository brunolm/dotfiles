function rm-rf {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  Remove-Item -Path $Path -Recurse -Force
}
