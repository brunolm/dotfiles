# Windows Session Manager relaunches dwm.exe after it exits.
function B-PC-Restart-Dwm() {
  Stop-Process -Name dwm -Force
}
