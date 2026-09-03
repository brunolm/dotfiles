function rm-rf {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  Remove-Item -Path $Path -Recurse -Force
}

function cdcp {
  (Get-Location).Path | clip
}
