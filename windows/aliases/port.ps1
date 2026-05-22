function Kill-Port($port) {
  $processesOnPort = Get-NetTCPConnection -LocalPort $port -State Listen
  Write-Output $processesOnPort

  $connection = $processesOnPort | Select-Object -Property OwningProcess

  if ($connection.OwningProcess) {
    Stop-Process -Id $connection.OwningProcess
  }
}
