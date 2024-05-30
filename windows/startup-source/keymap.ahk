; Ditto Win + ' maps to Win + v
#v::#'

; =====================================================

; Raider GE76 keybord fixes
Home::PgUp
PgUp::Home
End::PgDn
PgDn::End

; =====================================================

; Copilot Voice
^#c:: ; This is a hotkey (Win+Ctrl+C).
  {
    CoordMode, Mouse, Screen ; Set the coordinate mode to be relative to the screen
    SetMouseDelay, -1 ; Make the mouse move instantly
    ; Store the current mouse position
    MouseGetPos, oldX, oldY

    CoordMode, Mouse, Window ; Set the coordinate mode to be relative to the active window

    ImageSearch, x, y, 2900, 1900, A_ScreenWidth, A_ScreenHeight, C:\\BrunoLM\\Projects\\dotfiles\\windows\\startup-source\\copilot-mic.png
    if ErrorLevel != 0 ; If the image was not found
    {
      Send, {LWin down}c{LWin up}
      Sleep, 500
      MouseMove, A_ScreenWidth - 5, A_ScreenHeight - 500, 1
      Sleep, 500
      ImageSearch, x, y, 2900, 1900, A_ScreenWidth, A_ScreenHeight, C:\\BrunoLM\\Projects\\dotfiles\\windows\\startup-source\\copilot-mic.png
    }

    SetMouseDelay, -1 ; Make the mouse move instantly
    MouseClick, left, %x%, %y%

    ; Restore the old mouse position
    CoordMode, Mouse, Screen ; Set the coordinate mode to be relative to the screen
    MouseMove, %oldX%, %oldY%, 0
  }
return

; =====================================================

; Visual Studio Code
#IfWinActive ahk_exe Code - Insiders.exe
^LButton::
  KeyWait, Ctrl
  Click
  Send {Ctrl down}{Alt down}{Shift down}{F1}{Ctrl up}{Alt up}{Shift up}
#IfWinActive
return

; =====================================================

