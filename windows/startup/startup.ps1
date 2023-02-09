try {
  Set-ExecutionPolicy RemoteSigned
}
catch {}

try {
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
}
catch {}

Get-ChildItem c:\system\startup | ForEach-Object { Start-Process $_.FullName -verb runas }
