; Ditto Win + ' maps to Win + v
#v::#'

; Rauder GE76 keybord fixes
Home::PgUp
PgUp::Home
End::PgDn
PgDn::End


#IfWinActive ahk_exe Code - Insiders.exe
^LButton::
Send {Ctrl down}d{Ctrl up}
#IfWinActive
return





; PoE
#IfWinActive, Path of Exile
{
    ^WheelUp::
    ^WheelDown::
    Send ^{LButton}
    return

    +WheelUp::
    +WheelDown::
    Send +{LButton}
    return

CapsLock::
While GetKeyState("CapsLock", "P")
{
    Send, {Control down}
    Click
    Send, {Control up}
    Sleep, 50 ; Adjust this value for the speed of repetition
}
return
}