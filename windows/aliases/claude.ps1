## Start-Claude: launch Claude interactively with effort set to auto.
function Start-Claude {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & claude --effort auto @Arguments
}

## Claude-Ask: ask Claude a prompt non-interactively and return the result inline.
function Claude-Ask {
  [CmdletBinding()]
  param(
    [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
    [string]$Effort,

    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Prompt
  )

  $args_ = @('-p')
  if ($PSBoundParameters.ContainsKey('Effort')) {
    $args_ += @('--effort', $Effort)
  }
  $args_ += ($Prompt -join ' ')

  & claude @args_
}
