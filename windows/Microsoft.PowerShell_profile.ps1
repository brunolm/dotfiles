try {
  Set-ExecutionPolicy RemoteSigned
} catch { }

Function projs($path) {
  cd "D:\BrunoLM\Projects\$path"
}

Function edit-profile {
  echo $Profile
  code $Profile
}

Function edit-aliases() {
  code $env:Home/aliases
}

Function edit-hosts {
  echo "C:\Windows\System32\drivers\etc\hosts"
  start -verb runas code "C:\Windows\System32\drivers\etc\hosts"
}

if (Test-Path $env:HOME) {
    Get-ChildItem $env:Home/aliases -Filter *.ps1  |
    Foreach-Object {
        . $_.FullName
    }
}
