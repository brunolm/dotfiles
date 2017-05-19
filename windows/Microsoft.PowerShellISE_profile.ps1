try {
    Set-ExecutionPolicy RemoteSigned
} catch { }

Set-Location "${env:HomeDrive}${env:HomePath}"
. "${env:HomeDrive}${env:HomePath}\profile.ps1"

# http://stackoverflow.com/a/38381054/340760
function Invoke-Git {
  <#
  .Synopsis
  Wrapper function that deals with Powershell's peculiar error output when Git uses the error stream.

  .Example
  Invoke-Git ThrowError
  $LASTEXITCODE

  #>
  [CmdletBinding()]
  param(
    [parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & {
    [CmdletBinding()]
    param(
        [parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InnerArgs
    )
    git.exe $InnerArgs
  } -ErrorAction SilentlyContinue -ErrorVariable fail @Arguments

  if ($fail) {
    $fail.Exception
  }
}

Set-Alias -Name git -Value Invoke-Git
