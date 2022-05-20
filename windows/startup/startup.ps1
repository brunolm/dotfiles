Get-ChildItem c:\system\startup | ForEach-Object { Start-Process $_.FullName }
