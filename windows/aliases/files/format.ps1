function B-Files-Format-HumanReadable {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true)]
    [object]$InputObject
  )

  begin {
    $items = [System.Collections.Generic.List[object]]::new()
  }

  process {
    if ($null -ne $InputObject) { $items.Add($InputObject) }
  }

  end {
    $items | Format-Table `
      -GroupBy @{ Label = 'Directory'; Expression = { Convert-Path $_.PSParentPath } } `
      -Property `
        @{ Label = 'Mode'; Expression = { $_.Mode }; Width = 13 },
        @{ Label = 'LastWriteTime'; Expression = { $_.LastWriteTime }; Width = 26 },
        @{
          Label     = 'Length'
          Alignment = 'Right'
          Width     = 8
          Expression = {
            if ($_.PSIsContainer -or $null -eq $_.Length) { return '' }
            $size = [double]$_.Length
            $units = 'B', 'K', 'M', 'G', 'T', 'P'
            $i = 0
            while ($size -ge 1024 -and $i -lt $units.Length - 1) {
              $size /= 1024
              $i++
            }
            if ($i -eq 0) { '{0}B' -f [int]$size }
            else { '{0:N1}{1}' -f $size, $units[$i] }
          }
        },
        Name
  }
}
