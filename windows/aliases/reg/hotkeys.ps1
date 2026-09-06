## B-Reg-Disable-AltShift: unassigns the Alt+Shift keyboard-layout switch hotkey (takes effect after sign-out)
function B-Reg-Disable-AltShift() {
  Set-ItemProperty -Path 'HKCU:\Keyboard Layout\Toggle' -Name 'Hotkey' -Value '3' -Type String
}

## B-Reg-Disable-WinV: disables the Win+V clipboard-history shortcut (takes effect after Explorer restart)
function B-Reg-Disable-WinV() {
  Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisabledHotkeys' -Value 'V' -Type String
}

## B-Reg-Disable-StickyKeys: turns Sticky Keys off and removes the Shift x5 hotkey that would prompt to enable it
function B-Reg-Disable-StickyKeys() {
  Set-ItemProperty -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Value '26' -Type String
}
