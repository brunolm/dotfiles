function B-PC-Disable-RealtimeProtection() {
  Set-MpPreference -DisableRealtimeMonitoring $true
}
